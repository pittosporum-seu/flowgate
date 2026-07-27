package com.njl.flowgate.server

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import com.njl.flowgate.server.dto.VpnStatusDto
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Default implementation of VpnStateProvider that:
 * - Listens to V2RAY_CONNECTION_INFO broadcasts for real-time status
 * - Exposes start/stop via a command queue (consumed by Flutter plugin layer)
 *
 * In Phase 1, start/stop commands are written to SharedPreferences and
 * the Flutter side polls or receives them via MethodChannel.
 * In Phase 3, this will directly control Xray without Flutter involvement.
 */
class DefaultVpnStateProvider(
    private val context: Context,
    private val logBuffer: LogBuffer
) : VpnStateProvider {

    companion object {
        private const val TAG = "VpnStateProvider"
        private const val ACTION_V2RAY_INFO = "V2RAY_CONNECTION_INFO"
        private const val PREFS_NAME = "flowgate_api_commands"
        private const val KEY_PENDING_COMMAND = "pending_cmd"
        private const val KEY_PENDING_CONFIG = "pending_config"
        private const val KEY_PENDING_REMARK = "pending_remark"
        private const val KEY_PENDING_PROXY_ONLY = "pending_proxy_only"
    }

    // Current state tracked from broadcasts
    @Volatile private var currentState = "disconnected"
    @Volatile private var currentDuration = "00:00:00"
    @Volatile private var currentUploadSpeed: Long = 0
    @Volatile private var currentDownloadSpeed: Long = 0
    @Volatile private var currentUploadTotal: Long = 0
    @Volatile private var currentDownloadTotal: Long = 0

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent == null) return
            try {
                val state = intent.getSerializableExtra("STATE")?.toString() ?: return
                val duration = intent.getStringExtra("DURATION") ?: "00:00:00"
                val upSpeed = intent.getLongExtra("UPLOAD_SPEED", 0)
                val downSpeed = intent.getLongExtra("DOWNLOAD_SPEED", 0)
                val upTotal = intent.getLongExtra("UPLOAD_TRAFFIC", 0)
                val downTotal = intent.getLongExtra("DOWNLOAD_TRAFFIC", 0)

                // Map V2RAY_STATES enum to our state strings
                val mappedState = when {
                    state.contains("CONNECTED") && !state.contains("DIS") -> "connected"
                    state.contains("CONNECTING") -> "connecting"
                    state.contains("DISCONNECTED") -> "disconnected"
                    else -> "disconnected"
                }

                val previousState = currentState
                currentState = mappedState
                currentDuration = duration
                currentUploadSpeed = upSpeed
                currentDownloadSpeed = downSpeed
                currentUploadTotal = upTotal
                currentDownloadTotal = downTotal

                logBuffer.add("DEBUG", TAG, "State: $mappedState, up=$upSpeed, down=$downSpeed")

                // Push SSE event on state change
                if (mappedState != previousState) {
                    val statusJson = Json.encodeToString(getStatus())
                    SseEventBus.tryEmit(SseEvent("state-change", statusJson))
                    logBuffer.add("INFO", TAG, "State changed: $previousState -> $mappedState")
                }

                // Push traffic event periodically (every broadcast = ~1s)
                val trafficJson = """{"up":$upSpeed,"down":$downSpeed,"upTotal":$upTotal,"downTotal":$downTotal}"""
                SseEventBus.tryEmit(SseEvent("traffic", trafficJson))

            } catch (e: Exception) {
                Log.e(TAG, "Error processing broadcast", e)
            }
        }
    }

    fun register() {
        val filter = IntentFilter(ACTION_V2RAY_INFO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        logBuffer.add("INFO", TAG, "Broadcast receiver registered")
    }

    fun unregister() {
        try {
            context.unregisterReceiver(receiver)
            logBuffer.add("INFO", TAG, "Broadcast receiver unregistered")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to unregister receiver", e)
        }
    }

    override fun getStatus(): VpnStatusDto {
        return VpnStatusDto(
            state = currentState,
            duration = currentDuration,
            uploadSpeed = currentUploadSpeed,
            downloadSpeed = currentDownloadSpeed,
            uploadTotal = currentUploadTotal,
            downloadTotal = currentDownloadTotal
        )
    }

    override fun startVpn(config: String?, remark: String, proxyOnly: Boolean) {
        logBuffer.add("INFO", TAG, "startVpn requested: remark=$remark, proxyOnly=$proxyOnly")
        // Write command to SharedPreferences for Flutter/plugin layer to consume
        prefs.edit()
            .putString(KEY_PENDING_COMMAND, "start")
            .putString(KEY_PENDING_CONFIG, config)
            .putString(KEY_PENDING_REMARK, remark)
            .putBoolean(KEY_PENDING_PROXY_ONLY, proxyOnly)
            .apply()

        // Also push SSE event
        SseEventBus.tryEmit(SseEvent("command", """{"action":"start","remark":"$remark"}"""))
    }

    override fun stopVpn() {
        logBuffer.add("INFO", TAG, "stopVpn requested")
        prefs.edit()
            .putString(KEY_PENDING_COMMAND, "stop")
            .remove(KEY_PENDING_CONFIG)
            .remove(KEY_PENDING_REMARK)
            .apply()

        SseEventBus.tryEmit(SseEvent("command", """{"action":"stop"}"""))
    }

    /**
     * Called by Flutter/plugin layer to consume pending commands.
     * Returns the command and clears it.
     */
    fun consumePendingCommand(): PendingCommand? {
        val cmd = prefs.getString(KEY_PENDING_COMMAND, null) ?: return null
        val config = prefs.getString(KEY_PENDING_CONFIG, null)
        val remark = prefs.getString(KEY_PENDING_REMARK, null)
        val proxyOnly = prefs.getBoolean(KEY_PENDING_PROXY_ONLY, false)

        // Clear the command
        prefs.edit().remove(KEY_PENDING_COMMAND).apply()

        return PendingCommand(
            action = cmd,
            config = config,
            remark = remark,
            proxyOnly = proxyOnly
        )
    }
}

data class PendingCommand(
    val action: String, // "start" or "stop"
    val config: String?,
    val remark: String?,
    val proxyOnly: Boolean
)
