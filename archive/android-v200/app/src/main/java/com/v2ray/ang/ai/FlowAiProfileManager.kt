package com.v2ray.ang.ai

import android.content.Context
import com.v2ray.ang.AppConfig
import com.v2ray.ang.handler.MmkvManager
import com.v2ray.ang.util.JsonUtil
import java.util.UUID

object FlowAiProfileManager {

    fun ensureDefaults() {
        val existing = loadProfilesRaw()
        val defaults = defaultProfiles()
        if (existing.isEmpty()) {
            saveProfilesRaw(defaults)
            MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_DEFAULT_PROFILE, defaults.first().id)
            MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_FALLBACK_PROFILE, defaults.getOrNull(1)?.id.orEmpty())
        } else {
            val existingIds = existing.map { it.id }.toSet()
            val missing = defaults.filterNot { it.id in existingIds }
            if (missing.isNotEmpty()) {
                existing.addAll(missing)
            }
            existing.forEach { profile ->
                if (profile.toolMode.isNullOrBlank()) {
                    profile.toolMode = defaultToolMode(FlowAiProtocol.fromValue(profile.protocol))
                }
                if (profile.adaptiveRoutePolicy.isNullOrBlank()) {
                    profile.adaptiveRoutePolicy = com.v2ray.ang.routing.AdaptiveRoutePolicy.AUTO.value
                }
            }
            saveProfilesRaw(existing)
        }
        if (MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_AUTONOMY).isNullOrBlank()) {
            MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_AUTONOMY, FlowAiAutonomy.PREVIEW.value)
        }
        if (MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_LOG_LEVEL).isNullOrBlank()) {
            MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_LOG_LEVEL, FlowAiLogLevel.DETAILED.value)
        }
    }

    fun getProfiles(): MutableList<FlowAiProfile> {
        ensureDefaults()
        return loadProfilesRaw()
    }

    fun getProfile(profileId: String?): FlowAiProfile? {
        return getProfiles().firstOrNull { it.id == profileId }
    }

    fun getDefaultProfile(): FlowAiProfile? {
        val id = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_DEFAULT_PROFILE)
        return getProfile(id) ?: getProfiles().firstOrNull { it.enabled }
    }

    fun getFallbackProfile(): FlowAiProfile? {
        val id = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_FALLBACK_PROFILE)
        return getProfile(id)?.takeIf { it.id != getDefaultProfile()?.id && it.enabled }
    }

    fun setDefault(profileId: String) {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_DEFAULT_PROFILE, profileId)
    }

    fun setFallback(profileId: String) {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_FALLBACK_PROFILE, profileId)
    }

    fun getAutonomy(): FlowAiAutonomy {
        return FlowAiAutonomy.fromValue(MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_AUTONOMY))
    }

    fun setAutonomy(value: FlowAiAutonomy) {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_AUTONOMY, value.value)
    }

    fun getLogLevel(): FlowAiLogLevel {
        return FlowAiLogLevel.fromValue(MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_LOG_LEVEL))
    }

    fun setLogLevel(value: FlowAiLogLevel) {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_LOG_LEVEL, value.value)
    }

    fun save(profile: FlowAiProfile) {
        val next = getProfiles()
        val index = next.indexOfFirst { it.id == profile.id }
        if (profile.id.isBlank()) profile.id = UUID.randomUUID().toString()
        if (index >= 0) {
            next[index] = profile
        } else {
            next.add(profile)
        }
        saveProfilesRaw(next)
    }

    fun duplicate(profile: FlowAiProfile): FlowAiProfile {
        val copy = profile.copy(
            id = UUID.randomUUID().toString(),
            name = "${profile.name} Copy",
            builtIn = false,
            lastStatus = null,
            lastLatencyMs = 0L
        )
        save(copy)
        return copy
    }

    fun delete(context: Context, profileId: String) {
        val next = getProfiles().filterNot { it.id == profileId }.toMutableList()
        saveProfilesRaw(next)
        FlowAiSecretStore.removeApiKey(context, profileId)
        if (MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_DEFAULT_PROFILE) == profileId) {
            MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_DEFAULT_PROFILE, next.firstOrNull()?.id.orEmpty())
        }
        if (MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_FALLBACK_PROFILE) == profileId) {
            MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_FALLBACK_PROFILE, next.getOrNull(1)?.id.orEmpty())
        }
    }

    fun updateStatus(profileId: String, status: String?, latencyMs: Long = 0L) {
        val profiles = getProfiles()
        profiles.firstOrNull { it.id == profileId }?.let {
            it.lastStatus = status
            it.lastLatencyMs = latencyMs
            saveProfilesRaw(profiles)
        }
    }

    fun getChatHistory(): MutableList<FlowAiChatMessage> {
        val raw = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_CHAT_HISTORY).orEmpty()
        if (raw.isBlank()) return mutableListOf()
        return JsonUtil.fromJson(raw, Array<FlowAiChatMessage>::class.java)?.toMutableList() ?: mutableListOf()
    }

    fun appendChat(message: FlowAiChatMessage) {
        val next = getChatHistory()
            .plus(message)
            .takeLast(30)
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_CHAT_HISTORY, JsonUtil.toJson(next))
    }

    fun clearChatHistory() {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_CHAT_HISTORY, "")
    }

    private fun loadProfilesRaw(): MutableList<FlowAiProfile> {
        val raw = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOWGATE_AI_PROFILES).orEmpty()
        if (raw.isBlank()) return mutableListOf()
        return JsonUtil.fromJson(raw, Array<FlowAiProfile>::class.java)?.toMutableList() ?: mutableListOf()
    }

    private fun saveProfilesRaw(profiles: List<FlowAiProfile>) {
        MmkvManager.encodeSettings(AppConfig.PREF_FLOWGATE_AI_PROFILES, JsonUtil.toJson(profiles))
    }

    private fun defaultProfiles(): MutableList<FlowAiProfile> {
        fun p(
            id: String,
            name: String,
            provider: String,
            protocol: FlowAiProtocol,
            baseUrl: String,
            model: String,
            tags: List<String>,
            temperature: Double = 0.2,
        ) = FlowAiProfile(
            id = id,
            name = name,
            provider = provider,
            protocol = protocol.value,
            baseUrl = baseUrl,
            model = model,
            tags = tags,
            temperature = temperature,
            toolMode = defaultToolMode(protocol),
            builtIn = true
        )

        return mutableListOf(
            p("xiaomi-codingplan-mimo-v2-5-pro", "Xiaomi CodingPlan MiMo V2.5 Pro", "Xiaomi CodingPlan", FlowAiProtocol.OPENAI, "https://token-plan-sgp.xiaomimimo.com/v1", "mimo-v2.5-pro", listOf(FlowAiTags.CODING, FlowAiTags.REASONING, FlowAiTags.LONG_CONTEXT)),
            p("xiaomi-codingplan-mimo-v2-5", "Xiaomi CodingPlan MiMo V2.5", "Xiaomi CodingPlan", FlowAiProtocol.OPENAI, "https://token-plan-sgp.xiaomimimo.com/v1", "mimo-v2.5", listOf(FlowAiTags.CODING, FlowAiTags.LONG_CONTEXT)),
            p("xiaomi-codingplan-mimo-v2-pro", "Xiaomi CodingPlan MiMo V2 Pro", "Xiaomi CodingPlan", FlowAiProtocol.OPENAI, "https://token-plan-sgp.xiaomimimo.com/v1", "mimo-v2-pro", listOf(FlowAiTags.CODING, FlowAiTags.REASONING)),
            p("deepseek-v4-flash", "DeepSeek V4 Flash", "DeepSeek", FlowAiProtocol.OPENAI, "https://api.deepseek.com", "deepseek-v4-flash", listOf(FlowAiTags.ROUTING, FlowAiTags.FAST)),
            p("deepseek-v4-pro", "DeepSeek V4 Pro", "DeepSeek", FlowAiProtocol.OPENAI, "https://api.deepseek.com", "deepseek-v4-pro", listOf(FlowAiTags.ROUTING, FlowAiTags.REASONING)),
            p("deepseek-chat-legacy", "DeepSeek Chat Legacy", "DeepSeek", FlowAiProtocol.OPENAI, "https://api.deepseek.com", "deepseek-chat", listOf(FlowAiTags.CUSTOM)),
            p("openai-gpt-5-2", "OpenAI GPT-5.2", "OpenAI", FlowAiProtocol.OPENAI, "https://api.openai.com", "gpt-5.2", listOf(FlowAiTags.REASONING, FlowAiTags.LONG_CONTEXT)),
            p("openai-gpt-5-2-codex", "OpenAI GPT-5.2 Codex", "OpenAI", FlowAiProtocol.OPENAI, "https://api.openai.com", "gpt-5.2-codex", listOf(FlowAiTags.CODING, FlowAiTags.REASONING)),
            p("claude-sonnet", "Claude Sonnet", "Anthropic", FlowAiProtocol.ANTHROPIC, "https://api.anthropic.com", "claude-sonnet-4-5", listOf(FlowAiTags.CODING, FlowAiTags.REASONING)),
            p("claude-opus", "Claude Opus", "Anthropic", FlowAiProtocol.ANTHROPIC, "https://api.anthropic.com", "claude-opus-4-5", listOf(FlowAiTags.REASONING, FlowAiTags.LONG_CONTEXT)),
            p("gemini-pro", "Gemini Pro", "Google Gemini", FlowAiProtocol.GEMINI, "https://generativelanguage.googleapis.com", "gemini-3-pro", listOf(FlowAiTags.REASONING, FlowAiTags.LONG_CONTEXT)),
            p("gemini-flash", "Gemini Flash", "Google Gemini", FlowAiProtocol.GEMINI, "https://generativelanguage.googleapis.com", "gemini-2.5-flash", listOf(FlowAiTags.FAST, FlowAiTags.ROUTING)),
            p("openrouter-auto", "OpenRouter Auto", "OpenRouter", FlowAiProtocol.OPENAI, "https://openrouter.ai/api", "openrouter/auto", listOf(FlowAiTags.CUSTOM, FlowAiTags.ROUTING)),
            p("groq-fast", "Groq Fast", "Groq", FlowAiProtocol.OPENAI, "https://api.groq.com/openai", "openai/gpt-oss-120b", listOf(FlowAiTags.FAST)),
            p("xai-grok-code", "xAI Grok Code", "xAI", FlowAiProtocol.OPENAI, "https://api.x.ai", "grok-code-fast-1", listOf(FlowAiTags.CODING, FlowAiTags.FAST)),
            p("moonshot-kimi", "Kimi K2", "Moonshot", FlowAiProtocol.OPENAI, "https://api.moonshot.cn", "kimi-k2-0711-preview", listOf(FlowAiTags.CODING, FlowAiTags.LONG_CONTEXT)),
            p("qwen-coder", "Qwen Coder", "Qwen", FlowAiProtocol.OPENAI, "https://dashscope.aliyuncs.com/compatible-mode", "qwen3-coder-plus", listOf(FlowAiTags.CODING)),
            p("local-openai", "Local OpenAI Compatible", "Local", FlowAiProtocol.OPENAI, "http://127.0.0.1:11434", "qwen2.5-coder:7b", listOf(FlowAiTags.CUSTOM, FlowAiTags.CODING), 0.1)
        )
    }

    fun defaultToolMode(protocol: FlowAiProtocol): String {
        return when (protocol) {
            FlowAiProtocol.OPENAI -> FlowAiToolMode.AUTO.value
            FlowAiProtocol.ANTHROPIC, FlowAiProtocol.GEMINI -> FlowAiToolMode.JSON_ONLY.value
        }
    }
}
