package com.v2ray.ang.handler

import android.content.Context
import com.v2ray.ang.AppConfig
import com.v2ray.ang.R
import com.v2ray.ang.core.CoreServiceManager
import com.v2ray.ang.dto.entities.RulesetItem
import com.v2ray.ang.enums.ConnectionState
import com.v2ray.ang.enums.FlowRoutePack
import com.v2ray.ang.enums.FlowSubscriptionUpdateMode
import com.v2ray.ang.enums.RouteMode
import com.v2ray.ang.extension.toTrafficString
import com.v2ray.ang.routing.RouteAction
import com.v2ray.ang.util.JsonUtil
import com.v2ray.ang.util.LogUtil
import java.text.DateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

object FlowGateModeManager {
    private const val PREF_LEGACY_FLOW_MODE = "pref_flowgate_mode"
    private const val PREF_FLOW_ROUTE_PACK = "pref_flowgate_route_pack"
    private const val PREF_SUBSCRIPTION_UPDATE_MODE = "pref_flowgate_subscription_update_mode"
    private const val PREF_LAST_MODE_ERROR = "pref_flowgate_last_mode_error"
    private const val PREF_DIAGNOSTIC_STATUS = "pref_flowgate_diagnostic_status"

    data class ApplyResult(
        val success: Boolean,
        val requiresRestart: Boolean = false,
        val message: String? = null,
    )

    data class RoutePackInfo(
        val routePack: FlowRoutePack,
        val title: String,
        val summary: String,
        val ruleCount: Int,
        val active: Boolean,
    )

    data class DashboardState(
        val mode: RouteMode,
        val connectionState: ConnectionState,
        val routePack: FlowRoutePack,
        val appScope: String,
        val isRunning: Boolean,
        val selectedProfileName: String,
        val delayText: String,
        val proxyTrafficText: String,
        val directTrafficText: String,
        val lastSubscriptionUpdate: String,
        val lastError: String?,
        val diagnosticStatus: String?,
        val subscriptionUpdateMode: FlowSubscriptionUpdateMode,
        val serviceLines: List<FlowAdaptiveServiceManager.DashboardLine>,
    )

    data class ConfigSnapshot(
        val id: String = UUID.randomUUID().toString(),
        val createdAt: Long = System.currentTimeMillis(),
        val reason: String = "",
        val routeMode: String = "",
        val rulesJson: String = "",
        val settingsHash: String = "",
    )

    fun ensureInitialized(context: Context) {
        migrateLegacyMode()
        if (MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_ROUTE_MODE).isNullOrBlank()) {
            applyModeResult(context, RouteMode.SMART)
        }
        if (MmkvManager.decodeSettingsString(PREF_SUBSCRIPTION_UPDATE_MODE).isNullOrBlank()) {
            setSubscriptionUpdateMode(FlowSubscriptionUpdateMode.AUTO)
        }
        FlowAdaptiveServiceManager.ensureDefaults()
    }

    fun setConnectionState(state: ConnectionState) {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_CONNECTION_STATE, state.value)
    }

    fun getConnectionState(isRunning: Boolean): ConnectionState {
        return if (isRunning) {
            ConnectionState.CONNECTED
        } else {
            ConnectionState.fromValue(MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_CONNECTION_STATE))
        }.takeUnless { !isRunning && it == ConnectionState.CONNECTED } ?: ConnectionState.OFF
    }

    fun getMode(): RouteMode {
        migrateLegacyMode()
        return RouteMode.fromValue(MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_ROUTE_MODE))
    }

    fun getRoutePack(): FlowRoutePack {
        return FlowRoutePack.fromValue(MmkvManager.decodeSettingsString(PREF_FLOW_ROUTE_PACK))
    }

    fun getSubscriptionUpdateMode(): FlowSubscriptionUpdateMode {
        return FlowSubscriptionUpdateMode.fromValue(MmkvManager.decodeSettingsString(PREF_SUBSCRIPTION_UPDATE_MODE))
    }

    fun setSubscriptionUpdateMode(mode: FlowSubscriptionUpdateMode) {
        MmkvManager.encodeSettings(PREF_SUBSCRIPTION_UPDATE_MODE, mode.value)
    }

    fun applyChatGptRepair(context: Context): ApplyResult {
        val result = applyModeResult(context, RouteMode.SMART)
        if (result.success) {
            FlowAdaptiveServiceManager.forceServiceAction("openai", RouteAction.PROXY)
            FlowAdaptiveServiceManager.forceServiceAction("google_play", RouteAction.PROXY)
            val routeResult = applyCompiledRulesForMode(context, RouteMode.SMART, FlowRoutePack.SMART_CN)
            val status = if (routeResult.success) {
                context.getString(R.string.flow_chatgpt_repair_status_applied)
            } else {
                context.getString(R.string.flow_chatgpt_repair_status_failed, routeResult.message.orEmpty())
            }
            recordDiagnosticStatus(status)
            return routeResult
        }
        val status = context.getString(R.string.flow_chatgpt_repair_status_failed, result.message.orEmpty())
        recordDiagnosticStatus(status)
        return result
    }

    fun applyModeResult(context: Context, mode: RouteMode): ApplyResult {
        return runCatching {
            clearLastError()
            if (mode == RouteMode.CUSTOM) {
                markCustomRouting()
                return@runCatching ApplyResult(
                    success = true,
                    requiresRestart = true,
                    message = context.getString(R.string.flow_mode_custom_summary)
                )
            }

            MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_ROUTE_MODE, mode.value)
            applyCommonVpnDefaults()
            disablePerAppProxy()

            val routePack = when (mode) {
                RouteMode.GLOBAL -> FlowRoutePack.GLOBAL
                RouteMode.SMART -> FlowRoutePack.SMART_CN
                RouteMode.BLOCK_CN -> FlowRoutePack.BLOCK_CN
                RouteMode.CUSTOM -> FlowRoutePack.CUSTOM
            }
            applyCompiledRulesForMode(context, mode, routePack)
        }.getOrElse { error ->
            val message = error.message ?: error.javaClass.simpleName
            recordLastError(message)
            LogUtil.e(AppConfig.TAG, "FlowGate: failed to apply mode $mode", error)
            ApplyResult(success = false, message = message)
        }
    }

    fun applyRoutePack(context: Context, routePack: FlowRoutePack) {
        applyRoutePackResult(context, routePack)
    }

    fun applyRoutePackResult(context: Context, routePack: FlowRoutePack): ApplyResult {
        return runCatching {
            clearLastError()
            if (routePack == FlowRoutePack.CUSTOM) {
                markCustomRouting()
                return@runCatching ApplyResult(success = true, requiresRestart = true)
            }

            val mode = when (routePack) {
                FlowRoutePack.GLOBAL -> RouteMode.GLOBAL
                FlowRoutePack.BLOCK_CN -> RouteMode.BLOCK_CN
                else -> RouteMode.SMART
            }
            MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_ROUTE_MODE, mode.value)
            applyCommonVpnDefaults()
            applyCompiledRulesForMode(context, mode, routePack)
        }.getOrElse { error ->
            val message = error.message ?: error.javaClass.simpleName
            recordLastError(message)
            LogUtil.e(AppConfig.TAG, "FlowGate: failed to apply route pack $routePack", error)
            ApplyResult(success = false, message = message)
        }
    }

    fun restoreDefaultsForCurrentMode(context: Context): ApplyResult {
        return applyModeResult(context, getMode().takeUnless { it == RouteMode.CUSTOM } ?: RouteMode.SMART)
    }

    fun markCustomRouting() {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_ROUTE_MODE, RouteMode.CUSTOM.value)
        MmkvManager.encodeSettings(PREF_FLOW_ROUTE_PACK, FlowRoutePack.CUSTOM.value)
    }

    fun recordLastError(message: String?) {
        MmkvManager.encodeSettings(PREF_LAST_MODE_ERROR, message.orEmpty())
    }

    fun clearLastError() {
        MmkvManager.encodeSettings(PREF_LAST_MODE_ERROR, "")
    }

    private fun recordDiagnosticStatus(message: String?) {
        MmkvManager.encodeSettings(PREF_DIAGNOSTIC_STATUS, message.orEmpty())
    }

    fun getDashboardState(context: Context, isRunning: Boolean): DashboardState {
        val selectedGuid = MmkvManager.getSelectServer().orEmpty()
        val selectedProfile = MmkvManager.decodeServerConfig(selectedGuid)
        val selectedName = selectedProfile?.remarks?.takeIf { it.isNotBlank() }
            ?: context.getString(R.string.flow_node_none)
        val delayMillis = MmkvManager.decodeServerAffiliationInfo(selectedGuid)?.testDelayMillis ?: 0L
        val delayText = if (delayMillis > 0) {
            context.getString(R.string.flow_delay_ms, delayMillis)
        } else {
            context.getString(R.string.flow_value_empty)
        }

        val (proxyTraffic, directTraffic) = if (isRunning) {
            readTrafficSnapshot(context)
        } else {
            context.getString(R.string.flow_value_empty) to context.getString(R.string.flow_value_empty)
        }

        val connectionState = if (!isRunning && selectedGuid.isBlank()) {
            ConnectionState.NO_NODE
        } else {
            getConnectionState(isRunning)
        }

        return DashboardState(
            mode = getMode(),
            connectionState = connectionState,
            routePack = getRoutePack(),
            appScope = appScopeSummary(context),
            isRunning = isRunning,
            selectedProfileName = selectedName,
            delayText = delayText,
            proxyTrafficText = proxyTraffic,
            directTrafficText = directTraffic,
            lastSubscriptionUpdate = lastSubscriptionUpdateText(context),
            lastError = MmkvManager.decodeSettingsString(PREF_LAST_MODE_ERROR)?.takeIf { it.isNotBlank() },
            diagnosticStatus = MmkvManager.decodeSettingsString(PREF_DIAGNOSTIC_STATUS)?.takeIf { it.isNotBlank() },
            subscriptionUpdateMode = getSubscriptionUpdateMode(),
            serviceLines = FlowAdaptiveServiceManager.dashboardLines(context)
        )
    }

    fun routePackSummary(context: Context): String {
        val routePack = getRoutePack()
        val count = routePackRuleCount(context, routePack)
        return context.getString(R.string.flow_rule_pack_summary, context.getString(routePack.titleRes), count)
    }

    fun appScopeSummary(context: Context): String {
        val mode = getMode()
        if (mode == RouteMode.CUSTOM) {
            return context.getString(R.string.flow_app_scope_custom)
        }

        val perAppEnabled = MmkvManager.decodeSettingsBool(AppConfig.PREF_PER_APP_PROXY, false)
        if (!perAppEnabled) {
            return context.getString(R.string.flow_app_scope_all)
        }

        val selectedCount = MmkvManager.decodeSettingsStringSet(AppConfig.PREF_PER_APP_PROXY_SET)?.size ?: 0
        return context.getString(R.string.flow_app_scope_selected, selectedCount)
    }

    fun getRoutePackOptions(context: Context): List<RoutePackInfo> {
        val active = getRoutePack()
        return listOf(
            FlowRoutePack.SMART_CN,
            FlowRoutePack.SERVICE_ADAPTIVE,
            FlowRoutePack.BLOCK_CN,
            FlowRoutePack.GOOGLE_PLAY,
            FlowRoutePack.ADBLOCK,
            FlowRoutePack.STREAMING,
            FlowRoutePack.GLOBAL,
            FlowRoutePack.CUSTOM
        ).map {
            RoutePackInfo(
                routePack = it,
                title = context.getString(it.titleRes),
                summary = routePackDescription(context, it),
                ruleCount = routePackRuleCount(context, it),
                active = it == active
            )
        }
    }

    private fun applyCompiledRulesForMode(context: Context, mode: RouteMode, routePack: FlowRoutePack): ApplyResult {
        snapshotRules("apply:${mode.value}:${routePack.value}")
        val rules = rulesFor(context, mode, routePack)
        MmkvManager.encodeRoutingRulesets(rules)
        MmkvManager.encodeSettings(PREF_FLOW_ROUTE_PACK, routePack.value)
        return ApplyResult(success = true, requiresRestart = true)
    }

    private fun readTrafficSnapshot(context: Context): Pair<String, String> {
        return runCatching {
            val proxyUp = CoreServiceManager.queryStats(AppConfig.TAG_PROXY, AppConfig.UPLINK)
            val proxyDown = CoreServiceManager.queryStats(AppConfig.TAG_PROXY, AppConfig.DOWNLINK)
            val directUp = CoreServiceManager.queryStats(AppConfig.TAG_DIRECT, AppConfig.UPLINK)
            val directDown = CoreServiceManager.queryStats(AppConfig.TAG_DIRECT, AppConfig.DOWNLINK)

            formatTraffic(context, proxyUp, proxyDown) to formatTraffic(context, directUp, directDown)
        }.getOrElse {
            val empty = context.getString(R.string.flow_value_empty)
            empty to empty
        }
    }

    private fun formatTraffic(context: Context, up: Long, down: Long): String {
        return context.getString(R.string.flow_traffic_format, up.toTrafficString(), down.toTrafficString())
    }

    private fun lastSubscriptionUpdateText(context: Context): String {
        val lastUpdated = MmkvManager.decodeSubscriptions()
            .map { it.subscription.lastUpdated }
            .filter { it > 0L }
            .maxOrNull()

        if (lastUpdated == null) {
            return context.getString(R.string.flow_subscription_never)
        }

        val formatter = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT, Locale.getDefault())
        return formatter.format(Date(lastUpdated))
    }

    private fun routePackRuleCount(context: Context, routePack: FlowRoutePack): Int {
        return if (routePack == FlowRoutePack.CUSTOM) {
            MmkvManager.decodeRoutingRulesets()?.size ?: 0
        } else {
            rulesFor(context, modeForRoutePack(routePack), routePack).size
        }
    }

    private fun routePackDescription(context: Context, routePack: FlowRoutePack): String {
        return when (routePack) {
            FlowRoutePack.SMART_CN -> context.getString(R.string.flow_rule_pack_smart_cn_summary)
            FlowRoutePack.SERVICE_ADAPTIVE -> context.getString(R.string.flow_rule_pack_service_adaptive_summary)
            FlowRoutePack.BLOCK_CN -> context.getString(R.string.flow_rule_pack_block_cn_summary)
            FlowRoutePack.GOOGLE_PLAY -> context.getString(R.string.flow_rule_pack_google_play_summary)
            FlowRoutePack.ADBLOCK -> context.getString(R.string.flow_rule_pack_adblock_summary)
            FlowRoutePack.STREAMING -> context.getString(R.string.flow_rule_pack_streaming_summary)
            FlowRoutePack.GLOBAL -> context.getString(R.string.flow_rule_pack_global_summary)
            FlowRoutePack.CUSTOM -> context.getString(R.string.flow_rule_pack_custom_summary)
        }
    }

    private fun applyCommonVpnDefaults() {
        MmkvManager.encodeSettings(AppConfig.PREF_MODE, AppConfig.VPN)
        MmkvManager.encodeSettings(AppConfig.PREF_SNIFFING_ENABLED, true)
        MmkvManager.encodeSettings(AppConfig.PREF_LOCAL_DNS_ENABLED, true)
        MmkvManager.encodeSettings(AppConfig.PREF_ROUTE_ONLY_ENABLED, true)
        MmkvManager.encodeSettings(AppConfig.PREF_ENABLE_LOCAL_PROXY, true)
        MmkvManager.encodeSettings(AppConfig.PREF_SPEED_ENABLED, true)
        MmkvManager.encodeSettings(AppConfig.PREF_VPN_DNS, AppConfig.DNS_VPN)
        MmkvManager.encodeSettings(AppConfig.PREF_REMOTE_DNS, AppConfig.DNS_PROXY)
        MmkvManager.encodeSettings(AppConfig.PREF_DOMESTIC_DNS, AppConfig.DNS_DIRECT)
        applyStablePresetRoutingDefaults()
    }

    private fun applyStablePresetRoutingDefaults() {
        MmkvManager.encodeSettings(AppConfig.PREF_FAKE_DNS_ENABLED, false)
        MmkvManager.encodeSettings(AppConfig.PREF_ROUTING_DOMAIN_STRATEGY, "AsIs")
    }

    private fun disablePerAppProxy() {
        MmkvManager.encodeSettings(AppConfig.PREF_PER_APP_PROXY, false)
        MmkvManager.encodeSettings(AppConfig.PREF_BYPASS_APPS, false)
    }

    private fun rulesFor(context: Context, mode: RouteMode, routePack: FlowRoutePack): MutableList<RulesetItem> {
        return when (mode) {
            RouteMode.GLOBAL -> globalRules(context)
            RouteMode.SMART -> smartRules(context, routePack)
            RouteMode.BLOCK_CN -> blockCnRules(context)
            RouteMode.CUSTOM -> MmkvManager.decodeRoutingRulesets() ?: mutableListOf()
        }
    }

    private fun modeForRoutePack(routePack: FlowRoutePack): RouteMode {
        return when (routePack) {
            FlowRoutePack.GLOBAL -> RouteMode.GLOBAL
            FlowRoutePack.BLOCK_CN -> RouteMode.BLOCK_CN
            FlowRoutePack.CUSTOM -> RouteMode.CUSTOM
            else -> RouteMode.SMART
        }
    }

    private fun baseDirectRules(context: Context): MutableList<RulesetItem> {
        return mutableListOf(
            RulesetItem(
                remarks = context.getString(R.string.flow_rule_block_quic),
                port = "443",
                network = "udp",
                outboundTag = AppConfig.TAG_BLOCKED
            ),
            RulesetItem(
                remarks = context.getString(R.string.flow_rule_private_direct),
                ip = listOf(AppConfig.GEOIP_PRIVATE),
                domain = listOf(AppConfig.GEOSITE_PRIVATE),
                outboundTag = AppConfig.TAG_DIRECT
            )
        )
    }

    private fun smartRules(context: Context, routePack: FlowRoutePack): MutableList<RulesetItem> {
        return baseDirectRules(context).apply {
            addAll(FlowAdaptiveServiceManager.serviceRules(context))
            add(
                RulesetItem(
                    remarks = context.getString(R.string.flow_rule_pack_smart_cn),
                    ip = listOf(AppConfig.GEOIP_CN),
                    domain = listOf(AppConfig.GEOSITE_CN, AppConfig.GOOGLEAPIS_CN_DOMAIN),
                    outboundTag = AppConfig.TAG_DIRECT
                )
            )
            if (routePack == FlowRoutePack.GOOGLE_PLAY || routePack == FlowRoutePack.SERVICE_ADAPTIVE) {
                add(serviceFallbackProxyRule(context))
            }
            if (routePack == FlowRoutePack.ADBLOCK) {
                add(0, adBlockRule(context))
            }
            if (routePack == FlowRoutePack.STREAMING) {
                add(0, streamingRule(context))
            }
            add(
                RulesetItem(
                    remarks = context.getString(R.string.flow_rule_overseas_proxy),
                    domain = listOf("geosite:geolocation-!cn"),
                    outboundTag = AppConfig.TAG_PROXY
                )
            )
            add(finalDirectRule(context))
        }
    }

    private fun blockCnRules(context: Context): MutableList<RulesetItem> {
        return baseDirectRules(context).apply {
            add(
                RulesetItem(
                    remarks = context.getString(R.string.flow_rule_block_cn),
                    ip = listOf(AppConfig.GEOIP_CN),
                    domain = listOf(AppConfig.GEOSITE_CN, AppConfig.GOOGLEAPIS_CN_DOMAIN),
                    outboundTag = AppConfig.TAG_BLOCKED
                )
            )
            addAll(FlowAdaptiveServiceManager.serviceRules(context))
            add(finalProxyRule(context))
        }
    }

    private fun globalRules(context: Context): MutableList<RulesetItem> {
        return baseDirectRules(context).apply {
            add(finalProxyRule(context))
        }
    }

    private fun serviceFallbackProxyRule(context: Context): RulesetItem {
        return RulesetItem(
            remarks = context.getString(R.string.flow_rule_service_fallback_proxy),
            domain = openAiDomains() + googleDomains(),
            outboundTag = AppConfig.TAG_PROXY
        )
    }

    private fun adBlockRule(context: Context): RulesetItem {
        return RulesetItem(
            remarks = context.getString(R.string.flow_rule_pack_adblock),
            domain = listOf("geosite:category-ads-all"),
            outboundTag = AppConfig.TAG_BLOCKED
        )
    }

    private fun streamingRule(context: Context): RulesetItem {
        return RulesetItem(
            remarks = context.getString(R.string.flow_rule_pack_streaming),
            domain = listOf(
                "domain:youtube.com",
                "domain:googlevideo.com",
                "domain:ytimg.com",
                "domain:netflix.com",
                "domain:nflxvideo.net",
                "domain:disneyplus.com",
                "domain:hulu.com",
                "domain:spotify.com"
            ),
            outboundTag = AppConfig.TAG_PROXY
        )
    }

    private fun openAiDomains(): List<String> {
        return listOf(
            "domain:chatgpt.com",
            "domain:openai.com",
            "domain:api.openai.com",
            "domain:auth0.openai.com",
            "domain:ios.chat.openai.com",
            "domain:android.chat.openai.com",
            "domain:oaistatic.com",
            "domain:oaiusercontent.com",
            "domain:auth0.com",
            "domain:intercom.io",
            "domain:intercomcdn.com",
            "domain:events.statsigapi.net",
            "domain:featuregates.org"
        )
    }

    private fun googleDomains(): List<String> {
        return listOf(
            "domain:play.google.com",
            "domain:android.clients.google.com",
            "domain:gvt1.com",
            "domain:gvt2.com",
            "domain:google.com",
            "domain:googleapis.com",
            "domain:googleusercontent.com",
            "domain:ggpht.com",
            "domain:gstatic.com",
            "domain:googlevideo.com"
        )
    }

    private fun finalProxyRule(context: Context): RulesetItem {
        return RulesetItem(
            remarks = context.getString(R.string.flow_rule_final_proxy),
            port = "0-65535",
            outboundTag = AppConfig.TAG_PROXY
        )
    }

    private fun finalDirectRule(context: Context): RulesetItem {
        return RulesetItem(
            remarks = context.getString(R.string.flow_rule_final_direct),
            port = "0-65535",
            outboundTag = AppConfig.TAG_DIRECT
        )
    }

    private fun migrateLegacyMode() {
        val current = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_ROUTE_MODE)
        if (!current.isNullOrBlank()) return
        val legacy = MmkvManager.decodeSettingsString(PREF_LEGACY_FLOW_MODE)
        val migrated = RouteMode.fromValue(legacy)
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_ROUTE_MODE, migrated.value)
        if (legacy == "ai_google") {
            MmkvManager.encodeSettings(PREF_FLOW_ROUTE_PACK, FlowRoutePack.SERVICE_ADAPTIVE.value)
        }
    }

    private fun snapshotRules(reason: String) {
        val currentRules = JsonUtil.toJson(MmkvManager.decodeRoutingRulesets() ?: mutableListOf<RulesetItem>())
        val snapshot = ConfigSnapshot(
            reason = reason,
            routeMode = getMode().value,
            rulesJson = currentRules,
            settingsHash = currentRules.hashCode().toString()
        )
        val raw = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_CONFIG_SNAPSHOTS).orEmpty()
        val existing = if (raw.isBlank()) {
            mutableListOf()
        } else {
            JsonUtil.fromJson(raw, Array<ConfigSnapshot>::class.java)?.toMutableList() ?: mutableListOf()
        }
        existing.add(0, snapshot)
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_CONFIG_SNAPSHOTS, JsonUtil.toJson(existing.take(20)))
    }
}
