package com.njl.flowgate.server

import com.njl.flowgate.server.dto.*
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ConcurrentLinkedDeque

/**
 * System info and diagnostic endpoints.
 */
fun Route.systemRoutes(port: Int, logBuffer: LogBuffer) {

    get("/api/v1/system/info") {
        call.respond(HttpStatusCode.OK, ApiResponse(
            data = SystemInfoDto(
                version = "0.1.0",
                coreVersion = "Xray (via flutter_v2ray)",
                platform = "android",
                apiPort = port
            )
        ))
    }

    get("/api/v1/system/logs") {
        val limit = call.request.queryParameters["limit"]?.toIntOrNull() ?: 100
        val logs = logBuffer.getRecent(limit)
        call.respond(HttpStatusCode.OK, ApiResponse(
            data = LogsResponse(logs = logs, total = logBuffer.size())
        ))
    }
}

/**
 * Thread-safe circular log buffer for the API server.
 * Stores recent log entries for retrieval via /api/v1/system/logs.
 */
class LogBuffer(private val capacity: Int = 500) {
    private val buffer = ConcurrentLinkedDeque<LogEntryDto>()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)

    fun add(level: String, tag: String, message: String) {
        val entry = LogEntryDto(
            timestamp = dateFormat.format(Date()),
            level = level,
            tag = tag,
            message = message
        )
        buffer.addLast(entry)
        while (buffer.size > capacity) {
            buffer.pollFirst()
        }
    }

    fun getRecent(limit: Int): List<LogEntryDto> {
        return buffer.toList().takeLast(limit)
    }

    fun size(): Int = buffer.size
}
