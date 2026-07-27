package com.njl.flowgate.server.dto

import kotlinx.serialization.Serializable

@Serializable
data class RoutingRulesDto(
    val domainStrategy: String = "IPIfNonMatch",
    val rules: List<RoutingRuleDto> = emptyList(),
    val bypassLan: Boolean = true,
    val bypassChina: Boolean = false,
    val proxyDomains: List<String> = emptyList(),
    val directDomains: List<String> = emptyList(),
    val proxyIps: List<String> = emptyList(),
    val directIps: List<String> = emptyList()
) {
    companion object {
        fun default() = RoutingRulesDto(
            domainStrategy = "IPIfNonMatch",
            rules = listOf(
                RoutingRuleDto(
                    id = "rule-lan",
                    type = "field",
                    outboundTag = "direct",
                    ip = listOf("geoip:private"),
                    enabled = true,
                    priority = 0
                ),
                RoutingRuleDto(
                    id = "rule-block-ads",
                    type = "field",
                    outboundTag = "block",
                    domain = listOf("geosite:category-ads-all"),
                    enabled = true,
                    priority = 1
                )
            ),
            bypassLan = true,
            bypassChina = false
        )
    }
}

@Serializable
data class RoutingRuleDto(
    val id: String,
    val type: String = "field",
    val outboundTag: String, // "proxy", "direct", "block"
    val domain: List<String> = emptyList(),
    val ip: List<String> = emptyList(),
    val port: String? = null,
    val protocol: List<String> = emptyList(),
    val enabled: Boolean = true,
    val priority: Int = 0
)

@Serializable
data class RoutingUpdateRequest(
    val domainStrategy: String? = null,
    val rules: List<RoutingRuleDto>? = null,
    val bypassLan: Boolean? = null,
    val bypassChina: Boolean? = null,
    val proxyDomains: List<String>? = null,
    val directDomains: List<String>? = null,
    val proxyIps: List<String>? = null,
    val directIps: List<String>? = null
)
