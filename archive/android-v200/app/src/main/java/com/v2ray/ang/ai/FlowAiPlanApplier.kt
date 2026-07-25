package com.v2ray.ang.ai

import android.content.Context
import com.google.gson.JsonParser
import com.v2ray.ang.AppConfig
import com.v2ray.ang.dto.entities.RulesetItem
import com.v2ray.ang.handler.FlowGateModeManager
import com.v2ray.ang.handler.MmkvManager
import com.v2ray.ang.util.JsonUtil

object FlowAiPlanApplier {
    private val allowedTypes = setOf("app", "domain", "ip", "port")
    private val allowedTags = setOf(AppConfig.TAG_PROXY, AppConfig.TAG_DIRECT, AppConfig.TAG_BLOCKED, "block")

    data class ValidationResult(
        val success: Boolean,
        val plan: FlowAiPlan? = null,
        val message: String? = null,
    )

    data class ApplyResult(
        val success: Boolean,
        val appliedCount: Int = 0,
        val message: String? = null,
    )

    fun parse(raw: String?): ValidationResult {
        if (raw.isNullOrBlank()) return ValidationResult(false, message = "Empty model response")
        return runCatching {
            val json = extractJsonObject(raw)
            val plan = JsonUtil.fromJson(json, FlowAiPlan::class.java)
                ?: return ValidationResult(false, message = "Invalid JSON plan")
            val normalized = plan.copy(actions = plan.actions.take(80).mapNotNull { normalizeAction(it) })
            if (normalized.actions.isEmpty()) {
                ValidationResult(false, message = "No valid actions in plan")
            } else {
                ValidationResult(true, plan = normalized)
            }
        }.getOrElse {
            ValidationResult(false, message = it.message ?: it.javaClass.simpleName)
        }
    }

    fun apply(context: Context, plan: FlowAiPlan): ApplyResult {
        return runCatching {
            val existing = MmkvManager.decodeRoutingRulesets() ?: mutableListOf()
            val before = existing.size
            val selectedApps = MmkvManager.decodeSettingsStringSet(AppConfig.PREF_PER_APP_PROXY_SET) ?: mutableSetOf()
            val perAppAlreadyEnabled = MmkvManager.decodeSettingsBool(AppConfig.PREF_PER_APP_PROXY, false)
            val routeKeys = existing.map { routeKey(it) }.toMutableSet()

            plan.actions.forEach { action ->
                val item = toRulesetItem(action) ?: return@forEach
                val key = routeKey(item)
                if (key !in routeKeys) {
                    existing.add(item)
                    routeKeys.add(key)
                }
                if (action.type == "app" && action.outboundTag == AppConfig.TAG_PROXY) {
                    selectedApps.add(action.target)
                }
            }

            MmkvManager.encodeRoutingRulesets(existing)
            if (selectedApps.isNotEmpty()) {
                MmkvManager.encodeSettings(AppConfig.PREF_PER_APP_PROXY, true)
                MmkvManager.encodeSettings(AppConfig.PREF_BYPASS_APPS, false)
                MmkvManager.encodeSettings(AppConfig.PREF_PER_APP_PROXY_SET, selectedApps)
            }
            FlowGateModeManager.markCustomRouting()
            MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_LAST_PLAN, JsonUtil.toJson(plan))

            val applied = existing.size - before
            ApplyResult(true, appliedCount = applied)
        }.getOrElse {
            ApplyResult(false, message = it.message ?: it.javaClass.simpleName)
        }
    }

    private fun normalizeAction(action: FlowAiAction): FlowAiAction? {
        val type = action.type.lowercase().trim()
        if (type !in allowedTypes) return null
        val target = action.target.trim().takeIf { it.isNotBlank() } ?: return null
        var outbound = action.outboundTag.lowercase().trim()
        if (outbound == "blocked") outbound = AppConfig.TAG_BLOCKED
        if (outbound == "block") outbound = AppConfig.TAG_BLOCKED
        if (outbound !in allowedTags) return null
        return action.copy(
            type = type,
            target = target,
            outboundTag = outbound,
            risk = action.risk.ifBlank { "medium" }.lowercase().take(24),
            confidence = action.confidence.coerceIn(0.0, 1.0)
        )
    }

    private fun toRulesetItem(action: FlowAiAction): RulesetItem? {
        val remarks = "AI: " + (action.reason?.take(54)?.ifBlank { action.target } ?: action.target)
        return when (action.type) {
            "app" -> RulesetItem(
                remarks = remarks,
                process = listOf(action.target),
                outboundTag = action.outboundTag
            )

            "domain" -> RulesetItem(
                remarks = remarks,
                domain = listOf(normalizeDomain(action.target)),
                outboundTag = action.outboundTag
            )

            "ip" -> RulesetItem(
                remarks = remarks,
                ip = listOf(action.target),
                outboundTag = action.outboundTag
            )

            "port" -> RulesetItem(
                remarks = remarks,
                port = action.port?.takeIf { it.isNotBlank() } ?: action.target,
                network = action.network?.takeIf { it.isNotBlank() },
                outboundTag = action.outboundTag
            )

            else -> null
        }
    }

    private fun normalizeDomain(value: String): String {
        val trimmed = value.trim()
        return if (trimmed.startsWith("domain:") || trimmed.startsWith("geosite:") ||
            trimmed.startsWith("regexp:") || trimmed.startsWith("keyword:")
        ) {
            trimmed
        } else {
            "domain:$trimmed"
        }
    }

    private fun routeKey(item: RulesetItem): String {
        return listOf(
            item.outboundTag,
            item.process?.joinToString("|").orEmpty(),
            item.domain?.joinToString("|").orEmpty(),
            item.ip?.joinToString("|").orEmpty(),
            item.port.orEmpty(),
            item.network.orEmpty()
        ).joinToString("#")
    }

    private fun extractJsonObject(raw: String): String {
        val cleaned = raw
            .replace("```json", "")
            .replace("```", "")
            .trim()
        runCatching {
            JsonParser.parseString(cleaned)
            return cleaned
        }

        val start = cleaned.indexOf('{')
        val end = cleaned.lastIndexOf('}')
        if (start >= 0 && end > start) {
            val candidate = cleaned.substring(start, end + 1)
            JsonParser.parseString(candidate)
            return candidate
        }

        JsonParser.parseString(cleaned)
        return cleaned
    }
}
