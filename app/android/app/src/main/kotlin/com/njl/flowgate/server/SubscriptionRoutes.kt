package com.njl.flowgate.server

import com.njl.flowgate.server.dto.*
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import java.util.UUID

/**
 * Subscription management endpoints: CRUD and manual update trigger.
 */
fun Route.subscriptionRoutes(
    dataStore: DataStore,
    logBuffer: LogBuffer
) {
    route("/api/v1/subscriptions") {

        // GET /api/v1/subscriptions — list all subscriptions
        get {
            val subs = dataStore.loadSubscriptions()
            call.respond(HttpStatusCode.OK, ApiResponse(data = subs))
        }

        // GET /api/v1/subscriptions/{id} — get single subscription
        get("/{id}") {
            val id = call.parameters["id"] ?: return@get call.respond(
                HttpStatusCode.BadRequest, ApiResponse<SubscriptionDto>(ok = false, error = "Missing id")
            )
            val subs = dataStore.loadSubscriptions()
            val sub = subs.find { it.id == id }
            if (sub == null) {
                call.respond(HttpStatusCode.NotFound, ApiResponse<SubscriptionDto>(ok = false, error = "Subscription not found"))
            } else {
                call.respond(HttpStatusCode.OK, ApiResponse(data = sub))
            }
        }

        // POST /api/v1/subscriptions — add a subscription
        post {
            val request = try {
                call.receive<SubscriptionCreateRequest>()
            } catch (e: Exception) {
                return@post call.respond(HttpStatusCode.BadRequest,
                    ApiResponse<SubscriptionDto>(ok = false, error = "Invalid request: ${e.message}"))
            }

            if (request.url.isBlank()) {
                return@post call.respond(HttpStatusCode.BadRequest,
                    ApiResponse<SubscriptionDto>(ok = false, error = "URL is required"))
            }

            val sub = SubscriptionDto(
                id = UUID.randomUUID().toString(),
                name = request.name.ifBlank { "Subscription" },
                url = request.url,
                autoUpdate = request.autoUpdate,
                updateIntervalHours = request.updateIntervalHours,
                createdAt = System.currentTimeMillis()
            )

            val subs = dataStore.loadSubscriptions()
            subs.add(sub)
            dataStore.saveSubscriptions(subs)

            logBuffer.add("INFO", "SubRoutes", "Subscription added: ${sub.name}")
            call.respond(HttpStatusCode.Created, ApiResponse(data = sub))
        }

        // PUT /api/v1/subscriptions/{id} — update subscription settings
        put("/{id}") {
            val id = call.parameters["id"] ?: return@put call.respond(
                HttpStatusCode.BadRequest, ApiResponse<SubscriptionDto>(ok = false, error = "Missing id")
            )
            val request = try {
                call.receive<SubscriptionUpdateRequest>()
            } catch (e: Exception) {
                return@put call.respond(HttpStatusCode.BadRequest,
                    ApiResponse<SubscriptionDto>(ok = false, error = "Invalid request: ${e.message}"))
            }

            val subs = dataStore.loadSubscriptions()
            val idx = subs.indexOfFirst { it.id == id }
            if (idx < 0) {
                return@put call.respond(HttpStatusCode.NotFound,
                    ApiResponse<SubscriptionDto>(ok = false, error = "Subscription not found"))
            }

            val existing = subs[idx]
            val updated = existing.copy(
                name = request.name ?: existing.name,
                url = request.url ?: existing.url,
                autoUpdate = request.autoUpdate ?: existing.autoUpdate,
                updateIntervalHours = request.updateIntervalHours ?: existing.updateIntervalHours
            )
            subs[idx] = updated
            dataStore.saveSubscriptions(subs)

            logBuffer.add("INFO", "SubRoutes", "Subscription updated: ${updated.name}")
            call.respond(HttpStatusCode.OK, ApiResponse(data = updated))
        }

        // DELETE /api/v1/subscriptions/{id} — delete subscription (and optionally its nodes)
        delete("/{id}") {
            val id = call.parameters["id"] ?: return@delete call.respond(
                HttpStatusCode.BadRequest, ApiResponse<Unit>(ok = false, error = "Missing id")
            )
            val deleteNodes = call.request.queryParameters["deleteNodes"]?.toBoolean() ?: false

            val subs = dataStore.loadSubscriptions()
            val removed = subs.removeAll { it.id == id }
            if (!removed) {
                return@delete call.respond(HttpStatusCode.NotFound,
                    ApiResponse<Unit>(ok = false, error = "Subscription not found"))
            }
            dataStore.saveSubscriptions(subs)

            // Optionally remove associated nodes
            if (deleteNodes) {
                val nodes = dataStore.loadNodes()
                val before = nodes.size
                nodes.removeAll { it.subscriptionId == id }
                dataStore.saveNodes(nodes)
                logBuffer.add("INFO", "SubRoutes", "Subscription $id deleted with ${before - nodes.size} nodes")
            } else {
                logBuffer.add("INFO", "SubRoutes", "Subscription $id deleted (nodes kept)")
            }

            call.respond(HttpStatusCode.OK, ApiResponse(data = mapOf("deleted" to true)))
        }

        // POST /api/v1/subscriptions/{id}/update — trigger manual update
        post("/{id}/update") {
            val id = call.parameters["id"] ?: return@post call.respond(
                HttpStatusCode.BadRequest, ApiResponse<SubscriptionUpdateResult>(ok = false, error = "Missing id")
            )

            val subs = dataStore.loadSubscriptions()
            val sub = subs.find { it.id == id }
            if (sub == null) {
                return@post call.respond(HttpStatusCode.NotFound,
                    ApiResponse<SubscriptionUpdateResult>(ok = false, error = "Subscription not found"))
            }

            // In Phase 2, actual HTTP fetch is a placeholder.
            // The subscription update logic will be fully implemented in Phase 3
            // when we have proper HTTP client + node diff/merge.
            val result = SubscriptionUpdateResult(
                subscriptionId = id,
                nodesAdded = 0,
                nodesUpdated = 0,
                nodesRemoved = 0,
                error = "Subscription fetch not yet implemented (Phase 3)"
            )

            // Update lastUpdated timestamp
            val idx = subs.indexOfFirst { it.id == id }
            subs[idx] = sub.copy(lastUpdated = System.currentTimeMillis())
            dataStore.saveSubscriptions(subs)

            logBuffer.add("INFO", "SubRoutes", "Subscription update triggered: ${sub.name} (placeholder)")
            call.respond(HttpStatusCode.OK, ApiResponse(data = result))
        }
    }
}
