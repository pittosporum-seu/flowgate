package com.v2ray.ang.ai

import com.v2ray.ang.AppConfig
import com.v2ray.ang.routing.AdaptiveRoutePolicy

enum class FlowAiProtocol(val value: String) {
    OPENAI("openai_compatible"),
    ANTHROPIC("anthropic_messages"),
    GEMINI("gemini_generate_content");

    companion object {
        fun fromValue(value: String?): FlowAiProtocol {
            return entries.firstOrNull { it.value == value } ?: OPENAI
        }
    }
}

enum class FlowAiToolMode(val value: String) {
    AUTO("auto"),
    FUNCTION_CALL("function_call"),
    JSON_ONLY("json_only");

    companion object {
        fun fromValue(value: String?): FlowAiToolMode {
            return entries.firstOrNull { it.value == value } ?: AUTO
        }
    }
}

enum class FlowAiAutonomy(val value: String) {
    PREVIEW("preview"),
    SAFE_AUTO("safe_auto"),
    FULL_AUTO("full_auto");

    companion object {
        fun fromValue(value: String?): FlowAiAutonomy {
            return entries.firstOrNull { it.value == value } ?: PREVIEW
        }
    }
}

enum class FlowAiLogLevel(val value: String) {
    SUMMARY("summary"),
    DETAILED("detailed"),
    MANUAL("manual");

    companion object {
        fun fromValue(value: String?): FlowAiLogLevel {
            return entries.firstOrNull { it.value == value } ?: DETAILED
        }
    }
}

object FlowAiTags {
    const val ROUTING = "routing"
    const val FAST = "fast"
    const val REASONING = "reasoning"
    const val CODING = "coding"
    const val LONG_CONTEXT = "long_context"
    const val CUSTOM = "custom"
}

data class FlowAiProfile(
    var id: String = "",
    var name: String = "",
    var provider: String = "",
    var protocol: String = FlowAiProtocol.OPENAI.value,
    var baseUrl: String = "",
    var model: String = "",
    var tags: List<String> = emptyList(),
    var temperature: Double = 0.2,
    var toolMode: String? = null,
    var enabled: Boolean = true,
    var favorite: Boolean = false,
    var lastStatus: String? = null,
    var lastLatencyMs: Long = 0L,
    var builtIn: Boolean = false,
    var adaptiveRoutePolicy: String? = AdaptiveRoutePolicy.AUTO.value,
    var preferProxy: Boolean = false,
)

data class FlowAiInstalledApp(
    val label: String,
    val packageName: String,
    val uid: Int,
    val selectedForVpn: Boolean,
)

data class FlowAiAnalysisInput(
    val mode: String,
    val routePack: String,
    val autonomy: String,
    val logLevel: String,
    val selectedApps: List<String>,
    val installedApps: List<FlowAiInstalledApp>,
    val recentLogs: List<String>,
    val focus: String? = null,
)

data class FlowAiPlan(
    var summary: String = "",
    var actions: List<FlowAiAction> = emptyList(),
)

data class FlowAiAction(
    var type: String = "",
    var target: String = "",
    var outboundTag: String = AppConfig.TAG_PROXY,
    var network: String? = null,
    var port: String? = null,
    var reason: String? = null,
    var confidence: Double = 0.0,
    var risk: String = "medium",
)

data class FlowAiCallResult(
    val success: Boolean,
    val content: String? = null,
    val message: String? = null,
    val profile: FlowAiProfile? = null,
    val latencyMs: Long = 0L,
)

data class FlowAiChatMessage(
    val role: String = "assistant",
    val text: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val planSummary: String? = null,
    val error: String? = null,
)
