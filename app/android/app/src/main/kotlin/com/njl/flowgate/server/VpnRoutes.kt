package com.njl.flowgate.server

import com.njl.flowgate.server.dto.*
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * VPN control endpoints.
 * The server runs in the main process and delegates to flutter_v2ray's
 * V2rayCoreManager via the same broadcast mechanism used by the Flutter UI.
 */
fun Route.vpnRoutes(stateProvider: VpnStateProvider) {

    get("/api/v1/vpn/status") {
        val status = stateProvider.getStatus()
        call.respond(HttpStatusCode.OK, ApiResponse(data = status))
    }

    post("/api/v1/vpn/start") {
        val request = call.receive<VpnStartRequest>()
        try {
            stateProvider.startVpn(
                config = request.config,
                remark = request.remark ?: "api-start",
                proxyOnly = request.proxyOnly
            )
            call.respond(HttpStatusCode.OK, ApiResponse(
                data = VpnStartResponse(status = "starting")
            ))
        } catch (e: Exception) {
            call.respond(HttpStatusCode.InternalServerError, ApiResponse<VpnStartResponse>(
                ok = false,
                error = e.message ?: "Unknown error"
            ))
        }
    }

    post("/api/v1/vpn/stop") {
        try {
            stateProvider.stopVpn()
            call.respond(HttpStatusCode.OK, ApiResponse(
                data = VpnStartResponse(status = "stopping")
            ))
        } catch (e: Exception) {
            call.respond(HttpStatusCode.InternalServerError, ApiResponse<VpnStartResponse>(
                ok = false,
                error = e.message ?: "Unknown error"
            ))
        }
    }

    // SSE events endpoint
    sseEvents()
}

/**
 * Abstraction over VPN state - implemented by the server to bridge
 * between HTTP API and the flutter_v2ray plugin internals.
 */
interface VpnStateProvider {
    fun getStatus(): VpnStatusDto
    fun startVpn(config: String?, remark: String, proxyOnly: Boolean)
    fun stopVpn()
}
