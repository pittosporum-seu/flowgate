package com.njl.flowgate.server.dto

import kotlinx.serialization.Serializable

@Serializable
data class NodeDto(
    val id: String,
    val name: String,
    val type: String, // vmess, vless, trojan, shadowsocks, socks, hysteria2
    val server: String,
    val port: Int,
    val password: String = "",
    val method: String? = null,
    val sni: String? = null,
    val alpn: String? = null,
    val network: String? = null,
    val path: String? = null,
    val host: String? = null,
    val allowInsecure: Boolean = false,
    val subscriptionId: String? = null,
    val latencyMs: Int? = null,
    val createdAt: Long = 0,
    val rawConfig: String? = null
)

@Serializable
data class NodeListResponse(
    val nodes: List<NodeDto>,
    val total: Int
)

@Serializable
data class NodeImportRequest(
    val content: String,
    val type: String? = null, // "url", "raw", "base64", auto-detect if null
    val subscriptionId: String? = null
)

@Serializable
data class NodeImportResponse(
    val imported: Int,
    val nodes: List<NodeDto> = emptyList()
)

@Serializable
data class NodeTestResponse(
    val nodeId: String,
    val delay: Int? = null, // null = failed
    val error: String? = null
)

@Serializable
data class TestAllRequest(
    val groupIds: List<String>? = null // null = test all
)

@Serializable
data class TestAllResponse(
    val taskId: String,
    val total: Int
)

@Serializable
data class TestAllProgressResponse(
    val taskId: String,
    val completed: Int,
    val total: Int,
    val results: List<NodeTestResponse>
)
