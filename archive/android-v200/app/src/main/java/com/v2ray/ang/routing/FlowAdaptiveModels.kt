package com.v2ray.ang.routing

import com.v2ray.ang.AppConfig

enum class AdaptiveRoutePolicy(val value: String) {
    AUTO("auto"),
    FORCE_DIRECT("force_direct"),
    FORCE_PROXY("force_proxy"),
    DISABLED("disabled");

    companion object {
        fun fromValue(value: String?): AdaptiveRoutePolicy {
            return entries.firstOrNull { it.value == value } ?: AUTO
        }
    }
}

enum class CandidateRoute(val value: String) {
    DIRECT("direct"),
    PROXY("proxy"),
}

enum class RouteAction(val outboundTag: String) {
    PROXY(AppConfig.TAG_PROXY),
    DIRECT(AppConfig.TAG_DIRECT),
    BLOCK(AppConfig.TAG_BLOCKED),
    UNAVAILABLE("");

    companion object {
        fun fromOutboundTag(tag: String?): RouteAction {
            return when (tag) {
                AppConfig.TAG_DIRECT -> DIRECT
                AppConfig.TAG_BLOCKED -> BLOCK
                AppConfig.TAG_PROXY -> PROXY
                else -> UNAVAILABLE
            }
        }
    }
}

data class AppScope(
    val mode: AppScopeMode = AppScopeMode.ALL_APPS,
    val packageNames: Set<String> = emptySet(),
)

enum class AppScopeMode(val value: String) {
    ALL_APPS("all_apps"),
    INCLUDE_ONLY("include_only"),
    EXCLUDE_LIST("exclude_list");

    companion object {
        fun fromValue(value: String?): AppScopeMode {
            return entries.firstOrNull { it.value == value } ?: ALL_APPS
        }
    }
}

enum class ServiceCategory {
    AI_MODEL,
    GOOGLE,
    BROWSER,
    DEVELOPER,
    CUSTOM
}

enum class ProbeErrorType {
    DNS_FAILED,
    TCP_TIMEOUT,
    TLS_FAILED,
    HTTP_FAILED,
    AUTH_FAILED,
    RATE_LIMITED,
    SERVICE_UNAVAILABLE,
    UNKNOWN
}

enum class DecisionReason {
    DIRECT_ONLY_WORKS,
    PROXY_ONLY_WORKS,
    BOTH_WORK_DIRECT_PREFERRED,
    BOTH_WORK_PROXY_PREFERRED,
    BOTH_FAILED_LAST_KNOWN_GOOD,
    BOTH_FAILED_NO_ROUTE,
    BOTH_FAILED_NO_AVAILABLE_ROUTE,
    USER_FORCED_DIRECT,
    USER_FORCED_PROXY,
    USER_DISABLED_ADAPTIVE,
    MODE_BLOCK_CN,
    CUSTOM_RULE_OVERRIDE
}

enum class DecisionConfidence {
    HIGH,
    MEDIUM,
    LOW
}

enum class DecisionSource {
    PROBE,
    LAST_KNOWN_GOOD,
    USER_POLICY,
    SYSTEM_DEFAULT
}

data class ServiceTarget(
    val id: String = "",
    val title: String = "",
    val category: ServiceCategory = ServiceCategory.AI_MODEL,
    val domains: List<String> = emptyList(),
    val probeUrl: String = "",
    val policy: AdaptiveRoutePolicy = AdaptiveRoutePolicy.AUTO,
    val preferProxy: Boolean = false,
    val enabled: Boolean = true,
    val cnService: Boolean = false,
)

data class ServiceProbeResult(
    val serviceId: String = "",
    val route: CandidateRoute = CandidateRoute.DIRECT,
    val success: Boolean = false,
    val latencyMs: Long? = null,
    val errorType: ProbeErrorType? = null,
    val errorMessage: String? = null,
    val testedAt: Long = System.currentTimeMillis(),
)

data class ServiceProbeBundle(
    val service: ServiceTarget = ServiceTarget(),
    val direct: ServiceProbeResult? = null,
    val proxy: ServiceProbeResult? = null,
)

data class ServiceRoutingDecision(
    val serviceId: String = "",
    val action: RouteAction = RouteAction.UNAVAILABLE,
    val reason: DecisionReason = DecisionReason.BOTH_FAILED_NO_ROUTE,
    val directResult: ServiceProbeResult? = null,
    val proxyResult: ServiceProbeResult? = null,
    val confidence: DecisionConfidence = DecisionConfidence.LOW,
    val validUntil: Long = 0L,
    val source: DecisionSource = DecisionSource.SYSTEM_DEFAULT,
)

data class ServiceProbeHistory(
    val serviceId: String = "",
    val directSuccessStreak: Int = 0,
    val directFailureStreak: Int = 0,
    val proxySuccessStreak: Int = 0,
    val proxyFailureStreak: Int = 0,
    val lastTestedAt: Long = 0L,
)

data class EffectiveRoutingInput(
    val routeMode: com.v2ray.ang.enums.RouteMode,
    val appScope: AppScope = AppScope(),
    val serviceDecisions: List<ServiceRoutingDecision>,
    val settingsSummary: String = "",
)

data class EffectiveRoutingPlan(
    val rules: List<com.v2ray.ang.dto.entities.RulesetItem>,
    val requiresVpnRebuild: Boolean = true,
    val summary: String = "",
)

data class ApplyResult(
    val success: Boolean,
    val changeId: String = "",
    val message: String? = null,
)

data class RollbackResult(
    val success: Boolean,
    val message: String? = null,
)

enum class ApplyStrategy {
    SAVE_ONLY,
    APPLY_WITH_RESTART,
    APPLY_HOT_IF_POSSIBLE
}

interface RoutingEngine {
    suspend fun buildEffectivePlan(input: EffectiveRoutingInput): EffectiveRoutingPlan
    suspend fun applyPlan(plan: EffectiveRoutingPlan, strategy: ApplyStrategy): ApplyResult
    suspend fun rollback(changeId: String): RollbackResult
}

interface ServiceProbeEngine {
    suspend fun probeService(service: ServiceTarget): ServiceProbeBundle
    suspend fun probeAll(services: List<ServiceTarget>): List<ServiceProbeBundle>
}

interface AdaptiveRouteResolver {
    fun resolve(
        service: ServiceTarget,
        probeBundle: ServiceProbeBundle,
        lastKnownGood: ServiceRoutingDecision?,
    ): ServiceRoutingDecision
}
