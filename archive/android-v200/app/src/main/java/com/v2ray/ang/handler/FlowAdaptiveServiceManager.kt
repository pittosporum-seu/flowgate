package com.v2ray.ang.handler

import android.content.Context
import com.v2ray.ang.AppConfig
import com.v2ray.ang.R
import com.v2ray.ang.ai.FlowAiProfileManager
import com.v2ray.ang.core.CoreConfigManager
import com.v2ray.ang.core.CoreNativeManager
import com.v2ray.ang.dto.entities.RulesetItem
import com.v2ray.ang.routing.AdaptiveRoutePolicy
import com.v2ray.ang.routing.CandidateRoute
import com.v2ray.ang.routing.DecisionConfidence
import com.v2ray.ang.routing.DecisionReason
import com.v2ray.ang.routing.DecisionSource
import com.v2ray.ang.routing.ProbeErrorType
import com.v2ray.ang.routing.RouteAction
import com.v2ray.ang.routing.ServiceProbeBundle
import com.v2ray.ang.routing.ServiceProbeHistory
import com.v2ray.ang.routing.ServiceProbeResult
import com.v2ray.ang.routing.ServiceRoutingDecision
import com.v2ray.ang.routing.ServiceTarget
import com.v2ray.ang.util.JsonUtil
import com.v2ray.ang.util.LogUtil
import com.v2ray.ang.util.Utils
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.SocketTimeoutException
import java.net.URI
import java.net.UnknownHostException
import java.util.UUID
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLHandshakeException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import libv2ray.CoreCallbackHandler
import okhttp3.OkHttpClient
import okhttp3.Request

object FlowAdaptiveServiceManager {
    private const val MIN_PROBE_INTERVAL_MS = 5 * 60 * 1000L
    private const val DECISION_TTL_MS = 15 * 60 * 1000L
    private const val APPLY_COOLDOWN_MS = 30 * 1000L
    private const val PREF_LAST_APPLY_AT = "pref_flowgate_adaptive_last_apply_at"

    data class DashboardLine(
        val serviceId: String,
        val title: String,
        val summary: String,
        val action: RouteAction,
        val stale: Boolean,
    )

    data class ProbeRunResult(
        val updated: Int,
        val decisions: List<ServiceRoutingDecision>,
        val message: String,
    )

    fun ensureDefaults() {
        val current = loadTargetsRaw()
        val next = current.associateBy { it.id }.toMutableMap()
        defaultTargets().forEach { next.putIfAbsent(it.id, it) }
        modelProfileTargets().forEach { next.putIfAbsent(it.id, it) }
        saveTargetsRaw(next.values.sortedBy { it.title })
    }

    fun getTargets(): List<ServiceTarget> {
        ensureDefaults()
        return loadTargetsRaw().filter { it.enabled }
    }

    fun getPrimaryTargets(): List<ServiceTarget> {
        val primaryIds = setOf("deepseek", "openai", "google_play")
        return getTargets().filter { it.id in primaryIds }
    }

    fun getDecisions(): List<ServiceRoutingDecision> {
        val raw = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_SERVICE_DECISIONS).orEmpty()
        if (raw.isBlank()) return emptyList()
        return JsonUtil.fromJson(raw, Array<ServiceRoutingDecision>::class.java)?.toList().orEmpty()
    }

    fun getDecision(serviceId: String): ServiceRoutingDecision? {
        return getDecisions().firstOrNull { it.serviceId == serviceId }
    }

    fun serviceRules(context: Context): MutableList<RulesetItem> {
        val targets = getTargets().associateBy { it.id }
        val now = System.currentTimeMillis()
        return getDecisions()
            .filter { it.action != RouteAction.UNAVAILABLE }
            .filter { it.validUntil > now || it.source == DecisionSource.USER_POLICY || it.source == DecisionSource.LAST_KNOWN_GOOD }
            .mapNotNull { decision ->
                val service = targets[decision.serviceId] ?: return@mapNotNull null
                RulesetItem(
                    remarks = context.getString(
                        R.string.flow_service_rule_remarks,
                        service.title,
                        context.getString(actionTitle(decision.action))
                    ),
                    domain = service.domains,
                    outboundTag = decision.action.outboundTag
                )
            }
            .toMutableList()
    }

    fun dashboardLines(context: Context): List<DashboardLine> {
        val decisions = getDecisions().associateBy { it.serviceId }
        val now = System.currentTimeMillis()
        return getPrimaryTargets().map { target ->
            val decision = decisions[target.id]
            val action = decision?.action ?: RouteAction.UNAVAILABLE
            val stale = decision == null || (decision.validUntil <= now && decision.source != DecisionSource.USER_POLICY)
            DashboardLine(
                serviceId = target.id,
                title = target.title,
                summary = decisionSummary(context, decision),
                action = action,
                stale = stale
            )
        }
    }

    fun diagnosticReport(context: Context, isRunning: Boolean, routeModeTitle: String, nodeName: String): String {
        val lines = dashboardLines(context)
        val fakeDns = MmkvManager.decodeSettingsBool(AppConfig.PREF_FAKE_DNS_ENABLED, false)
        val appScope = FlowGateModeManager.appScopeSummary(context)
        val serviceText = lines.joinToString("\n") { "${it.title}: ${it.summary}" }
        val recentProblems = lines
            .filter { it.action == RouteAction.UNAVAILABLE || it.stale }
            .joinToString("\n") { "- ${it.title}: ${it.summary}" }
            .ifBlank { "- ${context.getString(R.string.flow_diagnostic_no_problem)}" }
        return """
            FlowGate ${context.getString(R.string.flow_diagnostic_report)}

            ${context.getString(R.string.flow_diagnostic_connection)}
            VPN: ${if (isRunning) context.getString(R.string.flow_status_connected) else context.getString(R.string.flow_status_disconnected)}
            ${context.getString(R.string.flow_current_mode)}: $routeModeTitle
            ${context.getString(R.string.flow_node_current)}: ${redact(nodeName)}

            ${context.getString(R.string.flow_service_availability)}
            $serviceText

            ${context.getString(R.string.flow_managed_apps)}
            $appScope

            DNS
            FakeDNS: ${if (fakeDns) "on" else "off"}

            ${context.getString(R.string.flow_diagnostic_recent_problems)}
            $recentProblems

            ${context.getString(R.string.flow_diagnostic_suggestions)}
            1. ${context.getString(R.string.flow_diagnostic_suggestion_smart)}
            2. ${context.getString(R.string.flow_diagnostic_suggestion_node)}
            3. ${context.getString(R.string.flow_diagnostic_suggestion_key)}
        """.trimIndent()
    }

    fun forceServiceAction(serviceId: String, action: RouteAction): ServiceRoutingDecision? {
        val target = getTargets().firstOrNull { it.id == serviceId } ?: return null
        val reason = when (action) {
            RouteAction.DIRECT -> DecisionReason.USER_FORCED_DIRECT
            RouteAction.PROXY -> DecisionReason.USER_FORCED_PROXY
            RouteAction.BLOCK -> DecisionReason.CUSTOM_RULE_OVERRIDE
            RouteAction.UNAVAILABLE -> DecisionReason.BOTH_FAILED_NO_ROUTE
        }
        val decision = ServiceRoutingDecision(
            serviceId = target.id,
            action = action,
            reason = reason,
            confidence = DecisionConfidence.HIGH,
            validUntil = System.currentTimeMillis() + DECISION_TTL_MS,
            source = DecisionSource.USER_POLICY
        )
        saveDecision(decision)
        return decision
    }

    fun clearForcedPolicy(serviceId: String) {
        val next = getDecisions().filterNot { it.serviceId == serviceId }
        saveDecisions(next)
    }

    suspend fun probePrimary(context: Context, force: Boolean = false): ProbeRunResult = withContext(Dispatchers.IO) {
        probeTargets(context, getPrimaryTargets(), force)
    }

    suspend fun probeService(context: Context, serviceId: String, force: Boolean = false): ServiceRoutingDecision? =
        withContext(Dispatchers.IO) {
            val target = getTargets().firstOrNull { it.id == serviceId } ?: return@withContext null
            probeTargets(context, listOf(target), force).decisions.firstOrNull()
        }

    private suspend fun probeTargets(context: Context, targets: List<ServiceTarget>, force: Boolean): ProbeRunResult {
        val now = System.currentTimeMillis()
        val decisions = mutableListOf<ServiceRoutingDecision>()
        targets.filter { it.enabled }.forEach { target ->
            val previous = getDecision(target.id)
            val lastHistory = loadHistory().firstOrNull { it.serviceId == target.id }
            if (!force && previous != null && previous.validUntil > now &&
                lastHistory != null && now - lastHistory.lastTestedAt < MIN_PROBE_INTERVAL_MS
            ) {
                decisions.add(previous)
                return@forEach
            }
            val direct = runProbe(context, target, CandidateRoute.DIRECT)
            val proxy = runProbe(context, target, CandidateRoute.PROXY)
            val history = updateHistory(target.id, direct, proxy)
            val decision = decide(target, direct, proxy, previous, history)
            saveDecision(decision)
            decisions.add(decision)
        }
        val message = context.getString(R.string.flow_service_probe_done, decisions.size)
        return ProbeRunResult(decisions.size, decisions, message)
    }

    private suspend fun runProbe(
        context: Context,
        service: ServiceTarget,
        route: CandidateRoute,
    ): ServiceProbeResult = withContext(Dispatchers.IO) {
        when (route) {
            CandidateRoute.DIRECT -> probeHttp(service, route, proxyPort = null)
            CandidateRoute.PROXY -> probeViaCurrentNode(context, service)
        }
    }

    private fun probeViaCurrentNode(context: Context, service: ServiceTarget): ServiceProbeResult {
        val guid = MmkvManager.getSelectServer().orEmpty()
        if (guid.isBlank()) {
            return ServiceProbeResult(
                serviceId = service.id,
                route = CandidateRoute.PROXY,
                success = false,
                errorType = ProbeErrorType.UNKNOWN,
                errorMessage = "No node selected"
            )
        }
        val port = Utils.findRandomFreePort()
        val config = CoreConfigManager.getV2rayConfig4HttpBenchmark(context, guid, port)
        if (!config.status) {
            return ServiceProbeResult(
                serviceId = service.id,
                route = CandidateRoute.PROXY,
                success = false,
                errorType = ProbeErrorType.UNKNOWN,
                errorMessage = config.errorMessage.ifBlank { "Proxy config failed" }
            )
        }

        CoreNativeManager.initCoreEnv(context)
        val controller = CoreNativeManager.newCoreController(object : CoreCallbackHandler {
            override fun startup(): Long = 0
            override fun shutdown(): Long = 0
            override fun onEmitStatus(l: Long, s: String?): Long = 0
        })

        return try {
            controller.startLoop(config.content, 0)
            if (!controller.isRunning) {
                ServiceProbeResult(
                    serviceId = service.id,
                    route = CandidateRoute.PROXY,
                    success = false,
                    errorType = ProbeErrorType.UNKNOWN,
                    errorMessage = "Benchmark core did not start"
                )
            } else {
                probeHttp(service, CandidateRoute.PROXY, proxyPort = port)
            }
        } catch (e: Exception) {
            ServiceProbeResult(
                serviceId = service.id,
                route = CandidateRoute.PROXY,
                success = false,
                errorType = mapProbeError(e),
                errorMessage = e.message ?: e.javaClass.simpleName
            )
        } finally {
            runCatching { controller.stopLoop() }
        }
    }

    private fun probeHttp(service: ServiceTarget, route: CandidateRoute, proxyPort: Int?): ServiceProbeResult {
        val started = System.currentTimeMillis()
        val builder = OkHttpClient.Builder()
            .connectTimeout(3, TimeUnit.SECONDS)
            .readTimeout(6, TimeUnit.SECONDS)
            .callTimeout(8, TimeUnit.SECONDS)
            .followRedirects(true)
            .followSslRedirects(true)
        if (proxyPort != null) {
            builder.proxy(Proxy(Proxy.Type.HTTP, InetSocketAddress(AppConfig.LOOPBACK, proxyPort)))
        }
        val request = Request.Builder()
            .url(service.probeUrl)
            .get()
            .header("User-Agent", "FlowGate/2.0")
            .build()
        return try {
            builder.build().newCall(request).execute().use { response ->
                val latency = System.currentTimeMillis() - started
                val reachable = response.code in 200..499
                ServiceProbeResult(
                    serviceId = service.id,
                    route = route,
                    success = reachable,
                    latencyMs = latency,
                    errorType = if (reachable) null else if (response.code == 429) ProbeErrorType.RATE_LIMITED else ProbeErrorType.HTTP_FAILED,
                    errorMessage = if (reachable) null else "HTTP ${response.code}",
                    testedAt = System.currentTimeMillis()
                )
            }
        } catch (e: Exception) {
            ServiceProbeResult(
                serviceId = service.id,
                route = route,
                success = false,
                errorType = mapProbeError(e),
                errorMessage = e.message ?: e.javaClass.simpleName,
                testedAt = System.currentTimeMillis()
            )
        }
    }

    private fun decide(
        service: ServiceTarget,
        direct: ServiceProbeResult,
        proxy: ServiceProbeResult,
        lastKnownGood: ServiceRoutingDecision?,
        history: ServiceProbeHistory,
    ): ServiceRoutingDecision {
        val now = System.currentTimeMillis()
        fun decision(action: RouteAction, reason: DecisionReason, confidence: DecisionConfidence, source: DecisionSource = DecisionSource.PROBE) =
            ServiceRoutingDecision(service.id, action, reason, direct, proxy, confidence, now + DECISION_TTL_MS, source)

        return when (service.policy) {
            AdaptiveRoutePolicy.FORCE_DIRECT -> decision(RouteAction.DIRECT, DecisionReason.USER_FORCED_DIRECT, DecisionConfidence.HIGH, DecisionSource.USER_POLICY)
            AdaptiveRoutePolicy.FORCE_PROXY -> decision(RouteAction.PROXY, DecisionReason.USER_FORCED_PROXY, DecisionConfidence.HIGH, DecisionSource.USER_POLICY)
            AdaptiveRoutePolicy.DISABLED -> decision(RouteAction.UNAVAILABLE, DecisionReason.BOTH_FAILED_NO_ROUTE, DecisionConfidence.LOW, DecisionSource.SYSTEM_DEFAULT)
            AdaptiveRoutePolicy.AUTO -> {
                val targetAction = when {
                    direct.success && !proxy.success -> RouteAction.DIRECT
                    !direct.success && proxy.success -> RouteAction.PROXY
                    direct.success && proxy.success && service.preferProxy -> RouteAction.PROXY
                    direct.success && proxy.success -> RouteAction.DIRECT
                    else -> RouteAction.UNAVAILABLE
                }
                val targetReason = when {
                    direct.success && !proxy.success -> DecisionReason.DIRECT_ONLY_WORKS
                    !direct.success && proxy.success -> DecisionReason.PROXY_ONLY_WORKS
                    direct.success && proxy.success && service.preferProxy -> DecisionReason.BOTH_WORK_PROXY_PREFERRED
                    direct.success && proxy.success -> DecisionReason.BOTH_WORK_DIRECT_PREFERRED
                    else -> DecisionReason.BOTH_FAILED_NO_ROUTE
                }
                if (targetAction == RouteAction.UNAVAILABLE) {
                    if (lastKnownGood != null && lastKnownGood.action != RouteAction.UNAVAILABLE && lastKnownGood.validUntil > now) {
                        lastKnownGood.copy(
                            reason = DecisionReason.BOTH_FAILED_LAST_KNOWN_GOOD,
                            confidence = DecisionConfidence.LOW,
                            source = DecisionSource.LAST_KNOWN_GOOD,
                            validUntil = now + DECISION_TTL_MS
                        )
                    } else {
                        decision(RouteAction.UNAVAILABLE, DecisionReason.BOTH_FAILED_NO_ROUTE, DecisionConfidence.LOW)
                    }
                } else {
                    val previousAction = lastKnownGood?.action
                    val switching = previousAction != null && previousAction != RouteAction.UNAVAILABLE && previousAction != targetAction
                    val targetSuccessStreak = if (targetAction == RouteAction.DIRECT) history.directSuccessStreak else history.proxySuccessStreak
                    val previousFailureStreak = if (previousAction == RouteAction.DIRECT) history.directFailureStreak else history.proxyFailureStreak
                    if (switching && targetSuccessStreak < 2 && previousFailureStreak < 2) {
                        lastKnownGood!!.copy(
                            reason = DecisionReason.BOTH_FAILED_LAST_KNOWN_GOOD,
                            confidence = DecisionConfidence.LOW,
                            source = DecisionSource.LAST_KNOWN_GOOD,
                            validUntil = now + DECISION_TTL_MS
                        )
                    } else {
                        decision(targetAction, targetReason, DecisionConfidence.HIGH)
                    }
                }
            }
        }
    }

    private fun updateHistory(serviceId: String, direct: ServiceProbeResult, proxy: ServiceProbeResult): ServiceProbeHistory {
        val histories = loadHistory().associateBy { it.serviceId }.toMutableMap()
        val old = histories[serviceId] ?: ServiceProbeHistory(serviceId = serviceId)
        val next = old.copy(
            directSuccessStreak = if (direct.success) old.directSuccessStreak + 1 else 0,
            directFailureStreak = if (!direct.success) old.directFailureStreak + 1 else 0,
            proxySuccessStreak = if (proxy.success) old.proxySuccessStreak + 1 else 0,
            proxyFailureStreak = if (!proxy.success) old.proxyFailureStreak + 1 else 0,
            lastTestedAt = System.currentTimeMillis()
        )
        histories[serviceId] = next
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_PROBE_HISTORY, JsonUtil.toJson(histories.values.toList()))
        return next
    }

    private fun loadHistory(): List<ServiceProbeHistory> {
        val raw = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_PROBE_HISTORY).orEmpty()
        if (raw.isBlank()) return emptyList()
        return JsonUtil.fromJson(raw, Array<ServiceProbeHistory>::class.java)?.toList().orEmpty()
    }

    private fun saveDecision(decision: ServiceRoutingDecision) {
        val next = getDecisions().associateBy { it.serviceId }.toMutableMap()
        next[decision.serviceId] = decision
        saveDecisions(next.values.toList())
        MmkvManager.encodeSettings(PREF_LAST_APPLY_AT, System.currentTimeMillis())
    }

    private fun saveDecisions(decisions: List<ServiceRoutingDecision>) {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_SERVICE_DECISIONS, JsonUtil.toJson(decisions))
    }

    private fun loadTargetsRaw(): MutableList<ServiceTarget> {
        val raw = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_ADAPTIVE_SERVICE_TARGETS).orEmpty()
        if (raw.isBlank()) return mutableListOf()
        return JsonUtil.fromJson(raw, Array<ServiceTarget>::class.java)?.toMutableList() ?: mutableListOf()
    }

    private fun saveTargetsRaw(targets: Collection<ServiceTarget>) {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_ADAPTIVE_SERVICE_TARGETS, JsonUtil.toJson(targets))
    }

    private fun defaultTargets(): List<ServiceTarget> = listOf(
        ServiceTarget(
            id = "deepseek",
            title = "DeepSeek",
            domains = listOf("domain:api.deepseek.com", "domain:deepseek.com"),
            probeUrl = "https://api.deepseek.com",
        ),
        ServiceTarget(
            id = "openai",
            title = "OpenAI / ChatGPT",
            domains = listOf(
                "domain:chatgpt.com",
                "domain:openai.com",
                "domain:api.openai.com",
                "domain:auth0.openai.com",
                "domain:ios.chat.openai.com",
                "domain:android.chat.openai.com",
                "domain:oaistatic.com",
                "domain:oaiusercontent.com",
                "domain:events.statsigapi.net",
                "domain:featuregates.org"
            ),
            probeUrl = "https://api.openai.com/v1/models",
            preferProxy = true
        ),
        ServiceTarget(
            id = "google_play",
            title = "Google Play",
            category = com.v2ray.ang.routing.ServiceCategory.GOOGLE,
            domains = listOf(
                "domain:play.google.com",
                "domain:android.clients.google.com",
                "domain:gvt1.com",
                "domain:gvt2.com",
                "domain:googleapis.com",
                "domain:gstatic.com",
                "domain:googleusercontent.com"
            ),
            probeUrl = "https://www.gstatic.com/generate_204",
            preferProxy = true
        ),
        ServiceTarget(
            id = "gemini",
            title = "Gemini",
            category = com.v2ray.ang.routing.ServiceCategory.GOOGLE,
            domains = listOf("domain:generativelanguage.googleapis.com", "domain:gemini.google.com"),
            probeUrl = "https://generativelanguage.googleapis.com"
        ),
        ServiceTarget(
            id = "claude",
            title = "Claude",
            domains = listOf("domain:anthropic.com", "domain:api.anthropic.com"),
            probeUrl = "https://api.anthropic.com"
        ),
        ServiceTarget(
            id = "openrouter",
            title = "OpenRouter",
            domains = listOf("domain:openrouter.ai"),
            probeUrl = "https://openrouter.ai/api/v1/models"
        ),
        ServiceTarget(
            id = "groq",
            title = "Groq",
            domains = listOf("domain:api.groq.com"),
            probeUrl = "https://api.groq.com/openai/v1/models"
        ),
        ServiceTarget(
            id = "kimi",
            title = "Kimi / Moonshot",
            domains = listOf("domain:api.moonshot.cn", "domain:moonshot.cn"),
            probeUrl = "https://api.moonshot.cn",
            cnService = true
        ),
        ServiceTarget(
            id = "qwen",
            title = "Qwen / Bailian",
            domains = listOf("domain:dashscope.aliyuncs.com"),
            probeUrl = "https://dashscope.aliyuncs.com",
            cnService = true
        ),
        ServiceTarget(
            id = "xai",
            title = "xAI",
            domains = listOf("domain:api.x.ai", "domain:x.ai"),
            probeUrl = "https://api.x.ai"
        ),
        ServiceTarget(
            id = "github",
            title = "GitHub",
            category = com.v2ray.ang.routing.ServiceCategory.DEVELOPER,
            domains = listOf("domain:github.com", "domain:githubusercontent.com", "domain:githubassets.com"),
            probeUrl = "https://github.com"
        ),
        ServiceTarget(
            id = "telegram",
            title = "Telegram",
            category = com.v2ray.ang.routing.ServiceCategory.CUSTOM,
            domains = listOf("domain:telegram.org", "domain:t.me", "domain:tdesktop.com"),
            probeUrl = "https://telegram.org"
        )
    )

    private fun modelProfileTargets(): List<ServiceTarget> {
        return runCatching {
            FlowAiProfileManager.getProfiles()
                .filter { it.enabled && it.baseUrl.isNotBlank() }
                .mapNotNull { profile ->
                    val host = hostFromUrl(profile.baseUrl) ?: return@mapNotNull null
                    ServiceTarget(
                        id = "model_${profile.id}",
                        title = profile.provider.ifBlank { profile.name },
                        domains = listOf("domain:$host"),
                        probeUrl = rootUrl(profile.baseUrl),
                        policy = AdaptiveRoutePolicy.fromValue(profile.adaptiveRoutePolicy),
                        preferProxy = profile.preferProxy,
                        enabled = profile.enabled
                    )
                }
        }.getOrElse {
            LogUtil.w(AppConfig.TAG, "FlowGate adaptive profile sync skipped: ${it.message}")
            emptyList()
        }
    }

    private fun hostFromUrl(url: String): String? {
        return runCatching { URI(url).host?.removePrefix("www.") }.getOrNull()
    }

    private fun rootUrl(url: String): String {
        return runCatching {
            val uri = URI(url)
            "${uri.scheme ?: "https"}://${uri.host}"
        }.getOrDefault(url)
    }

    private fun decisionSummary(context: Context, decision: ServiceRoutingDecision?): String {
        if (decision == null) return context.getString(R.string.flow_service_not_tested)
        return when (decision.action) {
            RouteAction.DIRECT -> context.getString(R.string.flow_service_direct_available)
            RouteAction.PROXY -> context.getString(R.string.flow_service_proxy_available)
            RouteAction.BLOCK -> context.getString(R.string.flow_service_blocked)
            RouteAction.UNAVAILABLE -> context.getString(R.string.flow_service_unavailable)
        }
    }

    private fun actionTitle(action: RouteAction): Int {
        return when (action) {
            RouteAction.DIRECT -> R.string.flow_route_action_direct
            RouteAction.PROXY -> R.string.flow_route_action_proxy
            RouteAction.BLOCK -> R.string.flow_route_action_block
            RouteAction.UNAVAILABLE -> R.string.flow_route_action_unavailable
        }
    }

    private fun mapProbeError(error: Throwable): ProbeErrorType {
        return when (error) {
            is UnknownHostException -> ProbeErrorType.DNS_FAILED
            is SocketTimeoutException -> ProbeErrorType.TCP_TIMEOUT
            is SSLHandshakeException -> ProbeErrorType.TLS_FAILED
            else -> ProbeErrorType.UNKNOWN
        }
    }

    private fun redact(text: String): String {
        return text
            .replace(Regex("(?i)(token|key|password|passwd|secret)=([^&\\s]+)"), "$1=<redacted>")
            .replace(Regex("(?i)(Bearer\\s+)[A-Za-z0-9._\\-]+"), "$1<redacted>")
    }

    fun newChangeId(): String = UUID.randomUUID().toString()
}
