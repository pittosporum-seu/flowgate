package com.v2ray.ang.ai

import android.content.Context
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.v2ray.ang.AppConfig
import com.v2ray.ang.util.JsonUtil
import com.v2ray.ang.util.LogUtil
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

object FlowAiClient {
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    suspend fun testProfile(context: Context, profile: FlowAiProfile): FlowAiCallResult {
        val prompt = "Return only this JSON object: {\"ok\":true,\"message\":\"ready\"}"
        return callModel(context, profile, prompt, maxTokens = 120, allowTools = false)
    }

    suspend fun analyze(context: Context, input: FlowAiAnalysisInput): FlowAiCallResult {
        val primary = FlowAiProfileManager.getDefaultProfile()
            ?: return FlowAiCallResult(false, message = "No AI profile")
        val fallback = FlowAiProfileManager.getFallbackProfile()

        val primaryResult = callModel(context, primary, buildRoutingPrompt(input), maxTokens = 1600)
        if (primaryResult.success || fallback == null) {
            return primaryResult
        }

        val fallbackResult = callModel(context, fallback, buildRoutingPrompt(input), maxTokens = 1600)
        return if (fallbackResult.success) fallbackResult else primaryResult
    }

    suspend fun chat(
        context: Context,
        userRequest: String,
        input: FlowAiAnalysisInput,
        history: List<FlowAiChatMessage>,
    ): FlowAiCallResult {
        val primary = FlowAiProfileManager.getDefaultProfile()
            ?: return FlowAiCallResult(false, message = "No AI profile")
        val fallback = FlowAiProfileManager.getFallbackProfile()
        val prompt = buildChatRoutingPrompt(userRequest, input, history)

        val primaryResult = callModel(context, primary, prompt, maxTokens = 1800)
        if (primaryResult.success || fallback == null) {
            return primaryResult
        }

        val fallbackResult = callModel(context, fallback, prompt, maxTokens = 1800)
        return if (fallbackResult.success) fallbackResult else primaryResult
    }

    private suspend fun callModel(
        context: Context,
        profile: FlowAiProfile,
        prompt: String,
        maxTokens: Int,
        allowTools: Boolean = true,
    ): FlowAiCallResult = withContext(Dispatchers.IO) {
        val started = System.currentTimeMillis()
        val apiKey = FlowAiSecretStore.readApiKey(context, profile.id)
        if (apiKey.isBlank()) {
            return@withContext FlowAiCallResult(false, message = "API key is not configured", profile = profile)
        }

        runCatching {
            val protocol = FlowAiProtocol.fromValue(profile.protocol)
            val result = when (protocol) {
                FlowAiProtocol.OPENAI -> {
                    val toolMode = if (allowTools) {
                        FlowAiToolMode.fromValue(profile.toolMode)
                    } else {
                        FlowAiToolMode.JSON_ONLY
                    }
                    val first = executeRequest(
                        protocol = protocol,
                        profile = profile,
                        request = openAiRequest(profile, apiKey, prompt, maxTokens, toolMode),
                        started = started,
                    )
                    if (!first.success && toolMode == FlowAiToolMode.AUTO && first.message.orEmpty().startsWith("HTTP 4")) {
                        executeRequest(
                            protocol = protocol,
                            profile = profile,
                            request = openAiRequest(profile, apiKey, prompt, maxTokens, FlowAiToolMode.JSON_ONLY),
                            started = started,
                        )
                    } else {
                        first
                    }
                }

                FlowAiProtocol.ANTHROPIC -> executeRequest(
                    protocol = protocol,
                    profile = profile,
                    request = anthropicRequest(profile, apiKey, prompt, maxTokens),
                    started = started,
                )

                FlowAiProtocol.GEMINI -> executeRequest(
                    protocol = protocol,
                    profile = profile,
                    request = geminiRequest(profile, apiKey, prompt, maxTokens),
                    started = started,
                )
            }
            result
        }.getOrElse {
            val latency = System.currentTimeMillis() - started
            val message = it.message ?: it.javaClass.simpleName
            FlowAiProfileManager.updateStatus(profile.id, message, latency)
            LogUtil.e(AppConfig.TAG, "FlowGate AI: model call failed", it)
            FlowAiCallResult(false, message = message, profile = profile, latencyMs = latency)
        }
    }

    private fun executeRequest(
        protocol: FlowAiProtocol,
        profile: FlowAiProfile,
        request: Request,
        started: Long,
    ): FlowAiCallResult {
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            val latency = System.currentTimeMillis() - started
            if (!response.isSuccessful) {
                val message = "HTTP ${response.code}: ${body.take(220)}"
                FlowAiProfileManager.updateStatus(profile.id, message, latency)
                return FlowAiCallResult(false, message = message, profile = profile, latencyMs = latency)
            }
            val content = extractContent(protocol, body)
            FlowAiProfileManager.updateStatus(profile.id, "OK", latency)
            return FlowAiCallResult(true, content = content, profile = profile, latencyMs = latency)
        }
    }

    private fun openAiRequest(
        profile: FlowAiProfile,
        apiKey: String,
        prompt: String,
        maxTokens: Int,
        toolMode: FlowAiToolMode,
    ): Request {
        val body = JsonObject().apply {
            addProperty("model", profile.model)
            addProperty("temperature", profile.temperature)
            addProperty("max_tokens", maxTokens)
            add("messages", JsonArray().apply {
                add(JsonObject().apply {
                    addProperty("role", "system")
                    addProperty("content", systemPrompt())
                })
                add(JsonObject().apply {
                    addProperty("role", "user")
                    addProperty("content", prompt)
                })
            })
            if (toolMode != FlowAiToolMode.JSON_ONLY) {
                add("tools", routingTools())
                add("tool_choice", JsonObject().apply {
                    addProperty("type", "function")
                    add("function", JsonObject().apply {
                        addProperty("name", "apply_routing_plan")
                    })
                })
            }
        }
        return Request.Builder()
            .url(normalizeOpenAiUrl(profile.baseUrl))
            .post(JsonUtil.toJson(body).toRequestBody(jsonMediaType))
            .header("Authorization", "Bearer $apiKey")
            .header("Content-Type", "application/json")
            .build()
    }

    private fun anthropicRequest(profile: FlowAiProfile, apiKey: String, prompt: String, maxTokens: Int): Request {
        val body = JsonObject().apply {
            addProperty("model", profile.model)
            addProperty("max_tokens", maxTokens)
            addProperty("temperature", profile.temperature)
            addProperty("system", systemPrompt())
            add("messages", JsonArray().apply {
                add(JsonObject().apply {
                    addProperty("role", "user")
                    addProperty("content", prompt)
                })
            })
        }
        return Request.Builder()
            .url(normalizeBase(profile.baseUrl) + "/v1/messages")
            .post(JsonUtil.toJson(body).toRequestBody(jsonMediaType))
            .header("x-api-key", apiKey)
            .header("anthropic-version", "2023-06-01")
            .header("Content-Type", "application/json")
            .build()
    }

    private fun geminiRequest(profile: FlowAiProfile, apiKey: String, prompt: String, maxTokens: Int): Request {
        val body = JsonObject().apply {
            add("generationConfig", JsonObject().apply {
                addProperty("temperature", profile.temperature)
                addProperty("maxOutputTokens", maxTokens)
            })
            add("contents", JsonArray().apply {
                add(JsonObject().apply {
                    add("parts", JsonArray().apply {
                        add(JsonObject().apply {
                            addProperty("text", systemPrompt() + "\n\n" + prompt)
                        })
                    })
                })
            })
        }
        val url = normalizeBase(profile.baseUrl) + "/v1beta/models/${profile.model}:generateContent?key=$apiKey"
        return Request.Builder()
            .url(url)
            .post(JsonUtil.toJson(body).toRequestBody(jsonMediaType))
            .header("Content-Type", "application/json")
            .build()
    }

    private fun extractContent(protocol: FlowAiProtocol, body: String): String {
        val root = JsonParser.parseString(body).asJsonObject
        return when (protocol) {
            FlowAiProtocol.OPENAI -> {
                val message = root.getAsJsonArray("choices")
                    ?.firstOrNull()?.asJsonObject
                    ?.getAsJsonObject("message")
                val toolArguments = message
                    ?.getAsJsonArray("tool_calls")
                    ?.mapNotNull { call ->
                        val function = call.asJsonObject.getAsJsonObject("function")
                        val name = function?.get("name")?.asString
                        if (name == "apply_routing_plan") {
                            function?.get("arguments")?.asString
                        } else {
                            null
                        }
                    }
                    ?.firstOrNull { it.isNotBlank() }
                toolArguments ?: message?.get("content")?.asString.orEmpty()
            }

            FlowAiProtocol.ANTHROPIC -> root.getAsJsonArray("content")
                ?.mapNotNull { it.asJsonObject.get("text")?.asString }
                ?.joinToString("\n").orEmpty()

            FlowAiProtocol.GEMINI -> root.getAsJsonArray("candidates")
                ?.firstOrNull()?.asJsonObject
                ?.getAsJsonObject("content")
                ?.getAsJsonArray("parts")
                ?.mapNotNull { it.asJsonObject.get("text")?.asString }
                ?.joinToString("\n").orEmpty()
        }
    }

    private fun buildRoutingPrompt(input: FlowAiAnalysisInput): String {
        val compact = JsonUtil.toJson(input)
        return """
            Analyze these FlowGate Android VPN observations and produce a previewable routing action card.
            FlowGate v1.4 no longer treats AI or Google as a route mode. AI/model services are service targets whose routes are decided by service availability: direct, proxy, block, or no change.
            The user wants practical, minimal routing for apps/domains/IPs: proxy, direct, or block.
            Return only strict JSON:
            {
              "summary": "short explanation",
              "actions": [
                {
                  "type": "app|domain|ip|port",
                  "target": "package/domain rule/ip cidr/port",
                  "outboundTag": "proxy|direct|block",
                  "network": "tcp|udp|tcp,udp optional",
                  "port": "optional port range",
                  "reason": "why",
                  "confidence": 0.0,
                  "risk": "low|medium|high"
                }
              ]
            }
            Structure the summary as: conclusion, reason, recommendation, applicable action.
            Prefer low-risk additions. For ChatGPT SSL issues, prefer OpenAI service/domain proxy and a node change suggestion; never propose certificate installation.
            If a tool/function call named apply_routing_plan is available, use it instead of free text.
            Do not propose certificate installation. Do not include secrets.

            Observations:
            $compact
        """.trimIndent()
    }

    private fun buildChatRoutingPrompt(
        userRequest: String,
        input: FlowAiAnalysisInput,
        history: List<FlowAiChatMessage>,
    ): String {
        val compact = JsonUtil.toJson(input)
        val recentChat = history.takeLast(8).joinToString("\n") {
            "${it.role}: ${it.text.take(600)}"
        }
        return """
            The user is chatting with FlowGate's Android VPN routing expert.
            FlowGate v1.4 treats DeepSeek, OpenAI, Google Play and model APIs as service targets, not modes.
            Reply by producing a safe routing plan. The plan summary should be natural and helpful because it will be shown as the assistant message.
            If the request is only a question, answer in summary and return an empty actions array.
            If a tool/function call named apply_routing_plan is available, use it.
            Answer with conclusion, reason, recommendation and applicable actions. Never propose installing certificates, exposing API keys, or copying subscription secrets.

            User request:
            $userRequest

            Recent chat:
            $recentChat

            Current diagnostics:
            $compact

            Required JSON shape:
            {
              "summary": "natural-language answer and diagnosis",
              "actions": []
            }
        """.trimIndent()
    }

    private fun systemPrompt(): String {
        return "You are FlowGate's routing expert. FlowGate has no AI/Google mode; AI and model APIs are service targets routed by availability. Produce safe, minimal Android VPN routing plans. Use the routing tool when available; otherwise return strict JSON only."
    }

    private fun routingTools(): JsonArray {
        return JsonArray().apply {
            add(JsonObject().apply {
                addProperty("type", "function")
                add("function", JsonObject().apply {
                    addProperty("name", "apply_routing_plan")
                    addProperty("description", "Return a previewable FlowGate Android VPN routing plan.")
                    add("parameters", routingPlanSchema())
                })
            })
        }
    }

    private fun routingPlanSchema(): JsonObject {
        return JsonObject().apply {
            addProperty("type", "object")
            add("required", JsonArray().apply {
                add("summary")
                add("actions")
            })
            add("properties", JsonObject().apply {
                add("summary", JsonObject().apply {
                    addProperty("type", "string")
                    addProperty("description", "Short human-readable diagnosis and intent.")
                })
                add("actions", JsonObject().apply {
                    addProperty("type", "array")
                    addProperty("maxItems", 80)
                    add("items", JsonObject().apply {
                        addProperty("type", "object")
                        add("required", JsonArray().apply {
                            add("type")
                            add("target")
                            add("outboundTag")
                            add("reason")
                            add("confidence")
                            add("risk")
                        })
                        add("properties", JsonObject().apply {
                            add("type", enumSchema("app", "domain", "ip", "port"))
                            add("target", JsonObject().apply {
                                addProperty("type", "string")
                                addProperty("description", "Android package, domain rule, IP CIDR, or port.")
                            })
                            add("outboundTag", enumSchema(AppConfig.TAG_PROXY, AppConfig.TAG_DIRECT, AppConfig.TAG_BLOCKED, "block"))
                            add("network", JsonObject().apply {
                                addProperty("type", "string")
                                addProperty("description", "Optional tcp, udp, or tcp,udp.")
                            })
                            add("port", JsonObject().apply {
                                addProperty("type", "string")
                                addProperty("description", "Optional port or port range.")
                            })
                            add("reason", JsonObject().apply {
                                addProperty("type", "string")
                            })
                            add("confidence", JsonObject().apply {
                                addProperty("type", "number")
                                addProperty("minimum", 0)
                                addProperty("maximum", 1)
                            })
                            add("risk", enumSchema("low", "medium", "high"))
                        })
                    })
                })
            })
        }
    }

    private fun enumSchema(vararg values: String): JsonObject {
        return JsonObject().apply {
            addProperty("type", "string")
            add("enum", JsonArray().apply {
                values.forEach { add(it) }
            })
        }
    }

    private fun normalizeOpenAiUrl(baseUrl: String): String {
        val base = normalizeBase(baseUrl)
        return if (base.endsWith("/v1")) "$base/chat/completions" else "$base/v1/chat/completions"
    }

    private fun normalizeBase(baseUrl: String): String {
        return baseUrl.trim().trimEnd('/').ifBlank { "https://api.deepseek.com" }
    }
}
