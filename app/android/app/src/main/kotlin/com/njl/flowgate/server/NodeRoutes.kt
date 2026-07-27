package com.njl.flowgate.server

import android.util.Base64
import com.njl.flowgate.server.dto.*
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.json.*
import java.util.UUID

/**
 * Node management endpoints: CRUD, import, and latency testing.
 */
fun Route.nodeRoutes(
    dataStore: DataStore,
    testService: NodeTestService,
    logBuffer: LogBuffer
) {
    route("/api/v1/nodes") {

        // GET /api/v1/nodes — list all nodes
        get {
            val nodes = dataStore.loadNodes()
            call.respond(HttpStatusCode.OK, ApiResponse(
                data = NodeListResponse(nodes = nodes, total = nodes.size)
            ))
        }

        // GET /api/v1/nodes/{id} — get single node
        get("/{id}") {
            val id = call.parameters["id"] ?: return@get call.respond(
                HttpStatusCode.BadRequest, ApiResponse<NodeDto>(ok = false, error = "Missing id")
            )
            val nodes = dataStore.loadNodes()
            val node = nodes.find { it.id == id }
            if (node == null) {
                call.respond(HttpStatusCode.NotFound, ApiResponse<NodeDto>(ok = false, error = "Node not found"))
            } else {
                call.respond(HttpStatusCode.OK, ApiResponse(data = node))
            }
        }

        // POST /api/v1/nodes — add a single node manually
        post {
            val request = try {
                call.receive<NodeDto>()
            } catch (e: Exception) {
                return@post call.respond(HttpStatusCode.BadRequest,
                    ApiResponse<NodeDto>(ok = false, error = "Invalid request body: ${e.message}"))
            }

            val nodes = dataStore.loadNodes()
            val node = request.copy(
                id = if (request.id.isBlank()) UUID.randomUUID().toString() else request.id,
                createdAt = if (request.createdAt == 0L) System.currentTimeMillis() else request.createdAt
            )
            nodes.add(node)
            dataStore.saveNodes(nodes)

            logBuffer.add("INFO", "NodeRoutes", "Node added: ${node.name} (${node.type})")
            call.respond(HttpStatusCode.Created, ApiResponse(data = node))
        }

        // POST /api/v1/nodes/import — batch import from URL/raw/base64
        post("/import") {
            val request = try {
                call.receive<NodeImportRequest>()
            } catch (e: Exception) {
                return@post call.respond(HttpStatusCode.BadRequest,
                    ApiResponse<NodeImportResponse>(ok = false, error = "Invalid request: ${e.message}"))
            }

            try {
                val parsed = parseImportContent(request.content, request.type)
                if (parsed.isEmpty()) {
                    return@post call.respond(HttpStatusCode.OK, ApiResponse(
                        data = NodeImportResponse(imported = 0)
                    ))
                }

                val nodes = dataStore.loadNodes()
                val now = System.currentTimeMillis()
                val newNodes = parsed.mapIndexed { index, raw ->
                    raw.copy(
                        id = UUID.randomUUID().toString(),
                        subscriptionId = request.subscriptionId,
                        createdAt = now + index
                    )
                }
                nodes.addAll(newNodes)
                dataStore.saveNodes(nodes)

                logBuffer.add("INFO", "NodeRoutes", "Imported ${newNodes.size} nodes")
                call.respond(HttpStatusCode.OK, ApiResponse(
                    data = NodeImportResponse(imported = newNodes.size, nodes = newNodes)
                ))
            } catch (e: Exception) {
                logBuffer.add("ERROR", "NodeRoutes", "Import failed: ${e.message}")
                call.respond(HttpStatusCode.InternalServerError, ApiResponse<NodeImportResponse>(
                    ok = false, error = "Import failed: ${e.message}"
                ))
            }
        }

        // DELETE /api/v1/nodes/{id} — delete a node
        delete("/{id}") {
            val id = call.parameters["id"] ?: return@delete call.respond(
                HttpStatusCode.BadRequest, ApiResponse<Unit>(ok = false, error = "Missing id")
            )
            val nodes = dataStore.loadNodes()
            val removed = nodes.removeAll { it.id == id }
            if (!removed) {
                call.respond(HttpStatusCode.NotFound, ApiResponse<Unit>(ok = false, error = "Node not found"))
            } else {
                dataStore.saveNodes(nodes)
                logBuffer.add("INFO", "NodeRoutes", "Node deleted: $id")
                call.respond(HttpStatusCode.OK, ApiResponse(data = mapOf("deleted" to true)))
            }
        }

        // POST /api/v1/nodes/{id}/test — test single node latency
        post("/{id}/test") {
            val id = call.parameters["id"] ?: return@post call.respond(
                HttpStatusCode.BadRequest, ApiResponse<NodeTestResponse>(ok = false, error = "Missing id")
            )
            val nodes = dataStore.loadNodes()
            val node = nodes.find { it.id == id }
            if (node == null) {
                return@post call.respond(HttpStatusCode.NotFound,
                    ApiResponse<NodeTestResponse>(ok = false, error = "Node not found"))
            }

            val result = testService.testNode(node)

            // Update node latency in store
            val updatedNodes = nodes.map {
                if (it.id == id) it.copy(latencyMs = result.delay) else it
            }
            dataStore.saveNodes(updatedNodes)

            call.respond(HttpStatusCode.OK, ApiResponse(data = result))
        }

        // POST /api/v1/nodes/test-all — start batch test
        post("/test-all") {
            val nodes = dataStore.loadNodes()
            if (nodes.isEmpty()) {
                return@post call.respond(HttpStatusCode.OK, ApiResponse(
                    data = TestAllResponse(taskId = "", total = 0)
                ))
            }

            val taskId = testService.startTestAll(nodes)
            call.respond(HttpStatusCode.OK, ApiResponse(
                data = TestAllResponse(taskId = taskId, total = nodes.size)
            ))
        }

        // GET /api/v1/nodes/test-all/{taskId} — poll test progress
        get("/test-all/{taskId}") {
            val taskId = call.parameters["taskId"] ?: return@get call.respond(
                HttpStatusCode.BadRequest, ApiResponse<TestAllProgressResponse>(ok = false, error = "Missing taskId")
            )
            val progress = testService.getProgress(taskId)
            if (progress == null) {
                call.respond(HttpStatusCode.NotFound,
                    ApiResponse<TestAllProgressResponse>(ok = false, error = "Task not found or expired"))
            } else {
                call.respond(HttpStatusCode.OK, ApiResponse(data = progress))
            }
        }
    }
}

/**
 * Parse import content into a list of NodeDto (without id/createdAt).
 * Supports: base64-encoded share links, raw share links (one per line).
 */
private fun parseImportContent(content: String, type: String?): List<NodeDto> {
    val decoded = when (type) {
        "base64" -> decodeBase64(content)
        "url" -> content // URL fetching would be done by caller/subscription service
        "raw" -> content
        else -> autoDetectAndDecode(content)
    }

    return decoded.lines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") }
        .mapNotNull { parseShareLink(it) }
}

private fun autoDetectAndDecode(content: String): String {
    // Try base64 decode if content looks like base64
    val trimmed = content.trim()
    if (trimmed.matches(Regex("^[A-Za-z0-9+/=\\s]+$")) && trimmed.length > 50) {
        try {
            val decoded = decodeBase64(trimmed)
            if (decoded.contains("://")) return decoded
        } catch (_: Exception) {}
    }
    return content
}

private fun decodeBase64(input: String): String {
    // Handle URL-safe base64 and missing padding
    val cleaned = input.replace("\n", "").replace("\r", "").trim()
    val padded = when (cleaned.length % 4) {
        2 -> "$cleaned=="
        3 -> "$cleaned="
        else -> cleaned
    }
    return try {
        String(Base64.decode(padded, Base64.DEFAULT))
    } catch (e: Exception) {
        String(Base64.decode(padded, Base64.URL_SAFE))
    }
}

/**
 * Parse a single share link into a NodeDto.
 * Supports: vmess://, vless://, trojan://, ss://, socks://, hysteria2://
 */
private fun parseShareLink(link: String): NodeDto? {
    return try {
        when {
            link.startsWith("vmess://") -> parseVmess(link)
            link.startsWith("vless://") -> parseVless(link)
            link.startsWith("trojan://") -> parseTrojan(link)
            link.startsWith("ss://") -> parseShadowsocks(link)
            link.startsWith("socks://") -> parseSocks(link)
            link.startsWith("hysteria2://") || link.startsWith("hy2://") -> parseHysteria2(link)
            else -> null
        }
    } catch (e: Exception) {
        null
    }
}

private fun parseVmess(link: String): NodeDto? {
    val b64 = link.removePrefix("vmess://")
    val jsonStr = String(Base64.decode(b64, Base64.DEFAULT))
    // vmess JSON format: {"v":"2","ps":"name","add":"server","port":"443","id":"uuid",...}
    val obj = Json.parseToJsonElement(jsonStr).jsonObject
    return NodeDto(
        id = "",
        name = obj["ps"]?.jsonPrimitive?.contentOrNull ?: "VMess Node",
        type = "vmess",
        server = obj["add"]?.jsonPrimitive?.contentOrNull ?: return null,
        port = obj["port"]?.jsonPrimitive?.contentOrNull?.toIntOrNull() ?: return null,
        password = obj["id"]?.jsonPrimitive?.contentOrNull ?: "",
        network = obj["net"]?.jsonPrimitive?.contentOrNull,
        path = obj["path"]?.jsonPrimitive?.contentOrNull,
        host = obj["host"]?.jsonPrimitive?.contentOrNull,
        sni = obj["sni"]?.jsonPrimitive?.contentOrNull,
        alpn = obj["alpn"]?.jsonPrimitive?.contentOrNull,
        allowInsecure = obj["allowInsecure"]?.jsonPrimitive?.contentOrNull == "1",
        rawConfig = link
    )
}

private fun parseVless(link: String): NodeDto? {
    // vless://uuid@server:port?params#name
    val withoutScheme = link.removePrefix("vless://")
    val hashIdx = withoutScheme.indexOf('#')
    val name = if (hashIdx >= 0) {
        java.net.URLDecoder.decode(withoutScheme.substring(hashIdx + 1), "UTF-8")
    } else "VLESS Node"
    val mainPart = if (hashIdx >= 0) withoutScheme.substring(0, hashIdx) else withoutScheme

    val atIdx = mainPart.indexOf('@')
    if (atIdx < 0) return null
    val uuid = mainPart.substring(0, atIdx)
    val rest = mainPart.substring(atIdx + 1)

    val queryIdx = rest.indexOf('?')
    val hostPort = if (queryIdx >= 0) rest.substring(0, queryIdx) else rest
    val query = if (queryIdx >= 0) rest.substring(queryIdx + 1) else ""

    val (server, port) = parseHostPort(hostPort) ?: return null
    val params = parseQuery(query)

    return NodeDto(
        id = "", name = name, type = "vless",
        server = server, port = port, password = uuid,
        network = params["type"],
        path = params["path"],
        host = params["host"],
        sni = params["sni"],
        alpn = params["alpn"],
        allowInsecure = params["allowInsecure"] == "1",
        rawConfig = link
    )
}

private fun parseTrojan(link: String): NodeDto? {
    // trojan://password@server:port?params#name
    val withoutScheme = link.removePrefix("trojan://")
    val hashIdx = withoutScheme.indexOf('#')
    val name = if (hashIdx >= 0) {
        java.net.URLDecoder.decode(withoutScheme.substring(hashIdx + 1), "UTF-8")
    } else "Trojan Node"
    val mainPart = if (hashIdx >= 0) withoutScheme.substring(0, hashIdx) else withoutScheme

    val atIdx = mainPart.indexOf('@')
    if (atIdx < 0) return null
    val password = mainPart.substring(0, atIdx)
    val rest = mainPart.substring(atIdx + 1)

    val queryIdx = rest.indexOf('?')
    val hostPort = if (queryIdx >= 0) rest.substring(0, queryIdx) else rest
    val query = if (queryIdx >= 0) rest.substring(queryIdx + 1) else ""

    val (server, port) = parseHostPort(hostPort) ?: return null
    val params = parseQuery(query)

    return NodeDto(
        id = "", name = name, type = "trojan",
        server = server, port = port, password = password,
        sni = params["sni"],
        alpn = params["alpn"],
        network = params["type"],
        path = params["path"],
        allowInsecure = params["allowInsecure"] == "1",
        rawConfig = link
    )
}

private fun parseShadowsocks(link: String): NodeDto? {
    // ss://base64(method:password)@server:port#name
    // or ss://base64(method:password@server:port)#name (SIP002)
    val withoutScheme = link.removePrefix("ss://")
    val hashIdx = withoutScheme.indexOf('#')
    val name = if (hashIdx >= 0) {
        java.net.URLDecoder.decode(withoutScheme.substring(hashIdx + 1), "UTF-8")
    } else "SS Node"
    val mainPart = if (hashIdx >= 0) withoutScheme.substring(0, hashIdx) else withoutScheme

    val atIdx = mainPart.indexOf('@')
    if (atIdx >= 0) {
        // userinfo@host:port format
        val userinfo = String(Base64.decode(mainPart.substring(0, atIdx), Base64.NO_WRAP))
        val hostPort = mainPart.substring(atIdx + 1)
        val colonIdx = userinfo.indexOf(':')
        if (colonIdx < 0) return null
        val method = userinfo.substring(0, colonIdx)
        val password = userinfo.substring(colonIdx + 1)
        val (server, port) = parseHostPort(hostPort) ?: return null

        return NodeDto(
            id = "", name = name, type = "shadowsocks",
            server = server, port = port, password = password,
            method = method, rawConfig = link
        )
    } else {
        // Full base64 format: base64(method:password@server:port)
        val decoded = String(Base64.decode(mainPart, Base64.DEFAULT))
        val colonIdx = decoded.indexOf(':')
        if (colonIdx < 0) return null
        val method = decoded.substring(0, colonIdx)
        val rest = decoded.substring(colonIdx + 1)
        val atIdx2 = rest.lastIndexOf('@')
        if (atIdx2 < 0) return null
        val password = rest.substring(0, atIdx2)
        val (server, port) = parseHostPort(rest.substring(atIdx2 + 1)) ?: return null

        return NodeDto(
            id = "", name = name, type = "shadowsocks",
            server = server, port = port, password = password,
            method = method, rawConfig = link
        )
    }
}

private fun parseSocks(link: String): NodeDto? {
    // socks://base64(user:pass)@server:port#name
    val withoutScheme = link.removePrefix("socks://")
    val hashIdx = withoutScheme.indexOf('#')
    val name = if (hashIdx >= 0) {
        java.net.URLDecoder.decode(withoutScheme.substring(hashIdx + 1), "UTF-8")
    } else "SOCKS Node"
    val mainPart = if (hashIdx >= 0) withoutScheme.substring(0, hashIdx) else withoutScheme

    val atIdx = mainPart.indexOf('@')
    if (atIdx < 0) return null
    val userinfo = try {
        String(Base64.decode(mainPart.substring(0, atIdx), Base64.NO_WRAP))
    } catch (e: Exception) { "" }
    val (server, port) = parseHostPort(mainPart.substring(atIdx + 1)) ?: return null
    val password = if (userinfo.contains(':')) userinfo.substringAfter(':') else userinfo

    return NodeDto(
        id = "", name = name, type = "socks",
        server = server, port = port, password = password,
        rawConfig = link
    )
}

private fun parseHysteria2(link: String): NodeDto? {
    // hysteria2://password@server:port?params#name
    val withoutScheme = link.removePrefix("hysteria2://").removePrefix("hy2://")
    val hashIdx = withoutScheme.indexOf('#')
    val name = if (hashIdx >= 0) {
        java.net.URLDecoder.decode(withoutScheme.substring(hashIdx + 1), "UTF-8")
    } else "Hysteria2 Node"
    val mainPart = if (hashIdx >= 0) withoutScheme.substring(0, hashIdx) else withoutScheme

    val atIdx = mainPart.indexOf('@')
    if (atIdx < 0) return null
    val password = mainPart.substring(0, atIdx)
    val rest = mainPart.substring(atIdx + 1)

    val queryIdx = rest.indexOf('?')
    val hostPort = if (queryIdx >= 0) rest.substring(0, queryIdx) else rest
    val query = if (queryIdx >= 0) rest.substring(queryIdx + 1) else ""

    val (server, port) = parseHostPort(hostPort) ?: return null
    val params = parseQuery(query)

    return NodeDto(
        id = "", name = name, type = "hysteria2",
        server = server, port = port, password = password,
        sni = params["sni"],
        alpn = params["alpn"],
        allowInsecure = params["insecure"] == "1",
        rawConfig = link
    )
}

// ─── Helpers ──────────────────────────────────────────────────────────────

private fun parseHostPort(hostPort: String): Pair<String, Int>? {
    // Handle IPv6: [::1]:443
    val trimmed = hostPort.trim()
    return if (trimmed.startsWith("[")) {
        val endBracket = trimmed.indexOf(']')
        if (endBracket < 0) return null
        val host = trimmed.substring(1, endBracket)
        val portStr = trimmed.substring(endBracket + 1).removePrefix(":")
        val port = portStr.toIntOrNull() ?: return null
        Pair(host, port)
    } else {
        val lastColon = trimmed.lastIndexOf(':')
        if (lastColon < 0) return null
        val host = trimmed.substring(0, lastColon)
        val port = trimmed.substring(lastColon + 1).toIntOrNull() ?: return null
        Pair(host, port)
    }
}

private fun parseQuery(query: String): Map<String, String> {
    if (query.isBlank()) return emptyMap()
    return query.split('&').mapNotNull { param ->
        val eqIdx = param.indexOf('=')
        if (eqIdx < 0) null
        else param.substring(0, eqIdx) to java.net.URLDecoder.decode(param.substring(eqIdx + 1), "UTF-8")
    }.toMap()
}
