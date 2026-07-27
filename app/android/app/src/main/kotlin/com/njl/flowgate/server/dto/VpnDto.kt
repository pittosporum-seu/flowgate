package com.njl.flowgate.server.dto

import kotlinx.serialization.Serializable

@Serializable
data class VpnStatusDto(
    val state: String, // "connected", "connecting", "disconnected", "disconnecting"
    val duration: String = "00:00:00",
    val uploadSpeed: Long = 0,
    val downloadSpeed: Long = 0,
    val uploadTotal: Long = 0,
    val downloadTotal: Long = 0,
    val nodeId: String? = null,
    val nodeName: String? = null
)

@Serializable
data class VpnStartRequest(
    val nodeId: String? = null,
    val config: String? = null,
    val remark: String? = null,
    val proxyOnly: Boolean = false
)

@Serializable
data class VpnStartResponse(
    val status: String,
    val message: String? = null
)

@Serializable
data class ApiResponse<T>(
    val ok: Boolean = true,
    val data: T? = null,
    val error: String? = null
)
