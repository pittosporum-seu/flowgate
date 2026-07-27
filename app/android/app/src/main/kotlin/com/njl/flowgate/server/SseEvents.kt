package com.njl.flowgate.server

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Manages Server-Sent Events for real-time status push.
 * Consumers (Flutter UI, AI agents) connect to GET /api/v1/vpn/events
 * and receive state changes, traffic updates, etc.
 */
object SseEventBus {
    private val _events = MutableSharedFlow<SseEvent>(
        replay = 0,
        extraBufferCapacity = 64
    )
    val events: Flow<SseEvent> = _events.asSharedFlow()

    suspend fun emit(event: SseEvent) {
        _events.emit(event)
    }

    fun tryEmit(event: SseEvent) {
        _events.tryEmit(event)
    }
}

data class SseEvent(
    val type: String, // "state-change", "traffic", "test-result", "log"
    val data: String  // JSON-encoded payload
)

fun Route.sseEvents() {
    get("/api/v1/vpn/events") {
        call.response.cacheControl(CacheControl.NoCache(null))
        call.response.header("X-Accel-Buffering", "no")
        call.respondTextWriter(contentType = ContentType.Text.EventStream) {
            SseEventBus.events.collect { event ->
                write("event: ${event.type}\n")
                write("data: ${event.data}\n\n")
                flush()
            }
        }
    }
}
