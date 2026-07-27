package com.flowgate.xray

import android.content.Context
import android.util.Log
import go.Seq
import libv2ray.CoreCallbackHandler
import libv2ray.CoreController
import libv2ray.Libv2ray
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Thin wrapper around libv2ray JNI calls.
 * Xray-core runs in-process via Go mobile bindings (libgojni.so).
 */
object XrayNativeBridge {
    private const val TAG = "XrayNativeBridge"
    private val initialized = AtomicBoolean(false)
    private lateinit var coreController: CoreController

    fun init(context: Context, callback: CoreCallbackHandler) {
        if (initialized.compareAndSet(false, true)) {
            Seq.setContext(context.applicationContext)
            val assetPath = context.applicationInfo.nativeLibraryDir
            // libv2ray expects geoip.dat / geosite.dat in filesDir/assets or nativeLibraryDir
            val filesAssetPath = "${context.filesDir.absolutePath}/assets"
            val actualAssetPath = if (java.io.File(filesAssetPath).exists()) filesAssetPath else assetPath
            Libv2ray.initCoreEnv(actualAssetPath, "")
            coreController = Libv2ray.newCoreController(callback)
            Log.i(TAG, "Xray core environment initialized")
        }
    }

    fun isInitialized(): Boolean = initialized.get()

    fun getController(): CoreController {
        check(initialized.get()) { "XrayNativeBridge not initialized" }
        return coreController
    }

    fun isRunning(): Boolean {
        return if (initialized.get()) coreController.isRunning else false
    }

    fun startLoop(config: String, tunFd: Int) {
        coreController.startLoop(config, tunFd.toLong())
    }

    fun stopLoop() {
        if (coreController.isRunning) {
            coreController.stopLoop()
        }
    }

    fun measureOutboundDelay(config: String, url: String): Long {
        return try {
            Libv2ray.measureOutboundDelay(config, url)
        } catch (e: Exception) {
            Log.e(TAG, "measureOutboundDelay failed", e)
            -1L
        }
    }

    fun measureDelay(url: String): Long {
        return try {
            coreController.measureDelay(url)
        } catch (e: Exception) {
            Log.e(TAG, "measureDelay failed", e)
            -1L
        }
    }

    fun queryStats(tag: String, link: String): Long {
        return try {
            coreController.queryStats(tag, link)
        } catch (e: Exception) {
            0L
        }
    }

    fun getVersion(): String {
        return try {
            Libv2ray.checkVersionX()
        } catch (e: Exception) {
            "unknown"
        }
    }
}
