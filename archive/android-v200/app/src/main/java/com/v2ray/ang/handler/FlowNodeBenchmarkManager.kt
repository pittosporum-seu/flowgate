package com.v2ray.ang.handler

import android.content.Context
import com.v2ray.ang.AppConfig
import com.v2ray.ang.core.CoreConfigManager
import com.v2ray.ang.core.CoreNativeManager
import com.v2ray.ang.util.LogUtil
import com.v2ray.ang.util.Utils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import libv2ray.CoreCallbackHandler

object FlowNodeBenchmarkManager {
    data class Result(
        val success: Boolean,
        val bps: Long = 0L,
        val message: String? = null,
    )

    suspend fun testDownload(context: Context, guid: String): Result = withContext(Dispatchers.IO) {
        if (guid.isBlank()) return@withContext Result(false, message = "No node selected")
        val url = MmkvManager.decodeSettingsString(AppConfig.PREF_FLOW_SPEED_TEST_URL, AppConfig.FLOW_SPEED_TEST_URL)
            ?: AppConfig.FLOW_SPEED_TEST_URL
        val size = MmkvManager.decodeSettingsLong(
            AppConfig.PREF_FLOW_SPEED_TEST_SIZE_BYTES,
            AppConfig.FLOW_SPEED_TEST_SIZE_BYTES
        ).coerceIn(128 * 1024L, 8 * 1024 * 1024L)
        val port = Utils.findRandomFreePort()
        val config = CoreConfigManager.getV2rayConfig4HttpBenchmark(context, guid, port)
        if (!config.status) {
            val msg = config.errorMessage.ifBlank { "Failed to build benchmark config" }
            MmkvManager.encodeServerDownloadBenchmark(guid, -1L, msg)
            return@withContext Result(false, message = msg)
        }

        CoreNativeManager.initCoreEnv(context)
        val controller = CoreNativeManager.newCoreController(object : CoreCallbackHandler {
            override fun startup(): Long = 0
            override fun shutdown(): Long = 0
            override fun onEmitStatus(l: Long, s: String?): Long = 0
        })

        try {
            controller.startLoop(config.content, 0)
            if (!controller.isRunning) {
                MmkvManager.encodeServerDownloadBenchmark(guid, -1L, "Benchmark core did not start")
                return@withContext Result(false, message = "Benchmark core did not start")
            }
            val bps = SpeedtestManager.downloadSpeedViaHttpProxy(url, port, 8000, size)
            if (bps > 0L) {
                MmkvManager.encodeServerDownloadBenchmark(guid, bps, "OK")
                Result(true, bps = bps)
            } else {
                MmkvManager.encodeServerDownloadBenchmark(guid, -1L, "Download test failed")
                Result(false, message = "Download test failed")
            }
        } catch (e: Exception) {
            val message = e.message ?: e.javaClass.simpleName
            MmkvManager.encodeServerDownloadBenchmark(guid, -1L, message)
            LogUtil.e(AppConfig.TAG, "FlowGate download benchmark failed", e)
            Result(false, message = message)
        } finally {
            runCatching { controller.stopLoop() }
        }
    }
}
