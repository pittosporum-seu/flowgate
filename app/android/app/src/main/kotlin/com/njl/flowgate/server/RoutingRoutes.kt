package com.njl.flowgate.server

import com.njl.flowgate.server.dto.*
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*

/**
 * Routing rules endpoints: get and update Xray routing configuration.
 */
fun Route.routingRoutes(
    dataStore: DataStore,
    logBuffer: LogBuffer
) {
    route("/api/v1/routing") {

        // GET /api/v1/routing — get current routing rules
        get {
            val rules = dataStore.loadRouting()
            call.respond(HttpStatusCode.OK, ApiResponse(data = rules))
        }

        // PUT /api/v1/routing — update routing rules (partial update supported)
        put {
            val request = try {
                call.receive<RoutingUpdateRequest>()
            } catch (e: Exception) {
                return@put call.respond(HttpStatusCode.BadRequest,
                    ApiResponse<RoutingRulesDto>(ok = false, error = "Invalid request: ${e.message}"))
            }

            val current = dataStore.loadRouting()
            val updated = current.copy(
                domainStrategy = request.domainStrategy ?: current.domainStrategy,
                rules = request.rules ?: current.rules,
                bypassLan = request.bypassLan ?: current.bypassLan,
                bypassChina = request.bypassChina ?: current.bypassChina,
                proxyDomains = request.proxyDomains ?: current.proxyDomains,
                directDomains = request.directDomains ?: current.directDomains,
                proxyIps = request.proxyIps ?: current.proxyIps,
                directIps = request.directIps ?: current.directIps
            )

            dataStore.saveRouting(updated)
            logBuffer.add("INFO", "RoutingRoutes", "Routing rules updated (strategy=${updated.domainStrategy}, rules=${updated.rules.size})")
            call.respond(HttpStatusCode.OK, ApiResponse(data = updated))
        }
    }
}
