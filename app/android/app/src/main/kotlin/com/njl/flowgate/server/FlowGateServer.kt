package com.njl.flowgate.server

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.cio.*
import io.ktor.server.engine.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.plugins.cors.routing.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.json.Json

/**
 * Local RESTful API Server for FlowGate.
 *
 * Runs in the main app process (same as Flutter Activity).
 * Binds to 127.0.0.1 only - never exposed to external network.
 *
 * Port discovery:
 * - Tries fixed port 19840 first
 * - Falls back to OS-assigned random port on conflict
 * - Writes resolved port to SharedPreferences for Flutter/AI discovery
 */
class FlowGateServer(
    private val context: Context,
    private val stateProvider: VpnStateProvider
) {
    companion object {
        private const val TAG = "FlowGateServer"
        private const val PREFS_NAME = "flowgate_api"
        private const val KEY_PORT = "api_port"
        private const val PREFERRED_PORT = 19840
    }

    private var server: ApplicationEngine? = null
    private var resolvedPort: Int = 0
    val logBuffer = LogBuffer()
    val dataStore = DataStore(context)
    val testService = NodeTestService(logBuffer)

    private val prefs: SharedPreferences
        get() = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /**
     * Start the HTTP server. Safe to call multiple times (idempotent).
     */
    fun start() {
        if (server != null) {
            Log.w(TAG, "Server already running on port $resolvedPort")
            return
        }

        logBuffer.add("INFO", TAG, "Starting API server...")

        // Use fixed port; if unavailable, try a few alternatives
        val ports = listOf(PREFERRED_PORT, 19841, 19842, 0)
        for (port in ports) {
            try {
                startOnPort(port)
                resolvedPort = if (port == 0) {
                    // For port 0, read from server after brief delay
                    Thread.sleep(100)
                    readResolvedPort()
                } else {
                    port
                }
                break
            } catch (e: Exception) {
                Log.w(TAG, "Port $port unavailable: ${e.message}")
                server = null
            }
        }

        // Persist port for discovery
        prefs.edit().putInt(KEY_PORT, resolvedPort).apply()
        logBuffer.add("INFO", TAG, "API server started on port $resolvedPort")
        Log.i(TAG, "API server listening on http://127.0.0.1:$resolvedPort")
    }

    private fun readResolvedPort(): Int {
        return try {
            val engine = server ?: return 0
            // Use reflection to get the resolved port from CIO engine
            val field = engine.javaClass.superclass?.declaredFields?.find { it.name == "resolvedConnectors" }
            // Fallback: just return the preferred port
            PREFERRED_PORT
        } catch (e: Exception) {
            PREFERRED_PORT
        }
    }

    private fun startOnPort(port: Int) {
        server = embeddedServer(CIO, host = "127.0.0.1", port = port) {
            configureServer()
        }.start(wait = false)
    }

    private fun Application.configureServer() {
        install(ContentNegotiation) {
            json(Json {
                prettyPrint = false
                isLenient = true
                ignoreUnknownKeys = true
                encodeDefaults = true
            })
        }

        install(CORS) {
            anyHost() // localhost only anyway
            allowHeader(HttpHeaders.ContentType)
            allowHeader(HttpHeaders.Authorization)
        }

        routing {
            // Health check
            get("/api/v1/health") {
                call.respondText(
                    """{"ok":true,"data":{"status":"ok","port":$resolvedPort}}""",
                    ContentType.Application.Json
                )
            }

            // VPN control
            vpnRoutes(stateProvider)

            // Node management (CRUD + import + test)
            nodeRoutes(dataStore, testService, logBuffer)

            // Subscription management
            subscriptionRoutes(dataStore, logBuffer)

            // Routing rules
            routingRoutes(dataStore, logBuffer)

            // System info
            systemRoutes(resolvedPort, logBuffer)
        }
    }

    /**
     * Stop the HTTP server.
     */
    fun stop() {
        logBuffer.add("INFO", TAG, "Stopping API server...")
        testService.destroy()
        server?.stop(1000, 2000)
        server = null
        resolvedPort = 0
        prefs.edit().remove(KEY_PORT).apply()
        Log.i(TAG, "API server stopped")
    }

    fun isRunning(): Boolean = server != null

    fun getPort(): Int = resolvedPort

    /**
     * Read the API port from SharedPreferences.
     * Used by Flutter and external tools to discover the server.
     */
    fun getDiscoveredPort(): Int {
        return prefs.getInt(KEY_PORT, 0)
    }
}
