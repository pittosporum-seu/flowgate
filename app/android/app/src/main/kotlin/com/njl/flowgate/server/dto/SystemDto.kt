package com.njl.flowgate.server.dto

import kotlinx.serialization.Serializable

@Serializable
data class SystemInfoDto(
    val version: String,
    val coreVersion: String,
    val platform: String = "android",
    val apiPort: Int
)

@Serializable
data class LogEntryDto(
    val timestamp: String,
    val level: String,
    val tag: String,
    val message: String
)

@Serializable
data class LogsResponse(
    val logs: List<LogEntryDto>,
    val total: Int
)
