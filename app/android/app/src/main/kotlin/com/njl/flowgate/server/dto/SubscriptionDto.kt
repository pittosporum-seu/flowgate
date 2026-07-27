package com.njl.flowgate.server.dto

import kotlinx.serialization.Serializable

@Serializable
data class SubscriptionDto(
    val id: String,
    val name: String,
    val url: String,
    val autoUpdate: Boolean = false,
    val updateIntervalHours: Int = 24,
    val lastUpdated: Long? = null,
    val nodeCount: Int = 0,
    val trafficUsed: Long? = null,
    val trafficTotal: Long? = null,
    val expireAt: Long? = null,
    val createdAt: Long = 0
)

@Serializable
data class SubscriptionCreateRequest(
    val name: String,
    val url: String,
    val autoUpdate: Boolean = false,
    val updateIntervalHours: Int = 24
)

@Serializable
data class SubscriptionUpdateRequest(
    val name: String? = null,
    val url: String? = null,
    val autoUpdate: Boolean? = null,
    val updateIntervalHours: Int? = null
)

@Serializable
data class SubscriptionUpdateResult(
    val subscriptionId: String,
    val nodesAdded: Int,
    val nodesUpdated: Int,
    val nodesRemoved: Int,
    val error: String? = null
)
