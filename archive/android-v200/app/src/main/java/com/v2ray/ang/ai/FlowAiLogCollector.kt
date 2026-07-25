package com.v2ray.ang.ai

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import com.v2ray.ang.AppConfig
import com.v2ray.ang.handler.FlowGateModeManager
import com.v2ray.ang.handler.MmkvManager
import com.v2ray.ang.util.LogUtil

object FlowAiLogCollector {
    private val secretPatterns = listOf(
        Regex("(?i)(authorization:\\s*bearer\\s+)[^\\s]+"),
        Regex("(?i)((api[_-]?key|token|secret|password|passwd)[=:]\\s*)[^\\s&]+"),
        Regex("(?i)(sk-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]+"),
        Regex("(?i)(vmess|vless|trojan|ss|hysteria2?|hy2)://[^\\s]+"),
        Regex("(?i)https?://[^\\s]*(token|api_key|apikey|secret|passwd|password|sub)[^\\s]*")
    )

    fun collect(context: Context, focus: String? = null): FlowAiAnalysisInput {
        val selectedApps = MmkvManager.decodeSettingsStringSet(AppConfig.PREF_PER_APP_PROXY_SET)?.toList().orEmpty()
        val logLevel = FlowAiProfileManager.getLogLevel()
        val logs = if (logLevel == FlowAiLogLevel.MANUAL) {
            emptyList()
        } else {
            loadRecentLogs().map { redact(it) }.take(if (logLevel == FlowAiLogLevel.DETAILED) 180 else 60)
        }

        return FlowAiAnalysisInput(
            mode = FlowGateModeManager.getMode().value,
            routePack = FlowGateModeManager.getRoutePack().value,
            autonomy = FlowAiProfileManager.getAutonomy().value,
            logLevel = logLevel.value,
            selectedApps = selectedApps,
            installedApps = loadInstalledApps(context, selectedApps).take(180),
            recentLogs = logs,
            focus = focus
        )
    }

    fun chatGptDiagnostic(context: Context): String {
        val selectedApps = MmkvManager.decodeSettingsStringSet(AppConfig.PREF_PER_APP_PROXY_SET).orEmpty()
        val logs = loadRecentLogs().take(120).map { redact(it) }
        val chatGptSelected = "com.openai.chatgpt" in selectedApps
        val proxyHits = logs.count { it.contains("openai", true) || it.contains("chatgpt", true) || it.contains("oai", true) }
        val sslErrors = logs.count { it.contains("ssl", true) || it.contains("tls", true) || it.contains("certificate", true) }
        val refused = logs.count { it.contains("refused", true) || it.contains("failed", true) }
        return buildString {
            append("ChatGPT package in VPN allowlist: ").append(chatGptSelected).append('\n')
            append("Recent OpenAI/ChatGPT related log lines: ").append(proxyHits).append('\n')
            append("Recent SSL/TLS/certificate log lines: ").append(sslErrors).append('\n')
            append("Recent refused/failed log lines: ").append(refused).append('\n')
            append("Current mode: ").append(FlowGateModeManager.getMode().value)
        }
    }

    private fun loadInstalledApps(context: Context, selectedApps: List<String>): List<FlowAiInstalledApp> {
        return runCatching {
            val pm = context.packageManager
            val apps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledApplications(android.content.pm.PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledApplications(0)
            }
            apps
                .filter { it.packageName != AppConfig.ANG_PACKAGE }
                .sortedWith(compareByDescending<ApplicationInfo> { it.packageName in selectedApps }
                    .thenBy { it.loadLabel(pm).toString().lowercase() })
                .map {
                    FlowAiInstalledApp(
                        label = it.loadLabel(pm).toString(),
                        packageName = it.packageName,
                        uid = it.uid,
                        selectedForVpn = it.packageName in selectedApps
                    )
                }
        }.getOrElse {
            LogUtil.e(AppConfig.TAG, "FlowGate AI: failed to load installed apps", it)
            emptyList()
        }
    }

    private fun loadRecentLogs(): List<String> {
        return runCatching {
            val process = Runtime.getRuntime().exec(
                arrayOf("logcat", "-d", "-v", "time", "-s", "GoLog,${AppConfig.ANG_PACKAGE},AndroidRuntime,System.err")
            )
            process.inputStream.bufferedReader().use { it.readLines() }.asReversed()
        }.getOrElse {
            LogUtil.e(AppConfig.TAG, "FlowGate AI: failed to read logcat", it)
            emptyList()
        }
    }

    fun redact(raw: String): String {
        var text = raw
        secretPatterns.forEach { pattern ->
            text = pattern.replace(text) { match ->
                val prefix = match.groups[1]?.value.orEmpty()
                if (prefix.isNotBlank() && !prefix.contains("://")) {
                    prefix + "<redacted>"
                } else {
                    "<redacted>"
                }
            }
        }
        return text.take(700)
    }
}

