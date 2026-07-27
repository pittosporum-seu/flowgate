package com.flowgate.xray

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FlowgateXrayPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var durationSeconds = 0
    private var statsTimer: Handler? = null

    companion object {
        private const val TAG = "FlowgateXrayPlugin"
        private const val VPN_REQUEST_CODE = 100
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "com.flowgate.xray/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.flowgate.xray/status")
        eventChannel.setStreamHandler(this)

        // Set up status callback from VpnService
        XrayVpnService.statusCallback = { state, dur, upSpeed, downSpeed, upTotal, downTotal ->
            mainHandler.post {
                eventSink?.success(mapOf(
                    "state" to state,
                    "duration" to dur,
                    "uplinkSpeed" to upSpeed,
                    "downlinkSpeed" to downSpeed,
                    "uplinkTotal" to upTotal,
                    "downlinkTotal" to downTotal
                ))
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        XrayVpnService.statusCallback = null
        stopStatsTimer()
    }

    // ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                try {
                    XrayNativeBridge.init(activity ?: return result.error("NO_ACTIVITY", null, null),
                        object : libv2ray.CoreCallbackHandler {
                            override fun startup(): Long = 0
                            override fun shutdown(): Long = 0
                            override fun onEmitStatus(l: Long, s: String?): Long = 0
                        })
                    result.success(null)
                } catch (e: Exception) {
                    result.error("INIT_FAILED", e.message, null)
                }
            }

            "startVpn" -> {
                val config = call.argument<String>("config")
                val remark = call.argument<String>("remark") ?: "FlowGate"
                if (config.isNullOrEmpty()) {
                    result.error("NO_CONFIG", "config is required", null)
                    return
                }

                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", null, null)
                    return
                }

                // Check VPN permission
                val vpnIntent = VpnService.prepare(act)
                if (vpnIntent != null) {
                    // Need to request permission - start activity for result
                    // For now, just try to start and let the system handle it
                    act.startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
                }

                val intent = Intent(act, XrayVpnService::class.java).apply {
                    putExtra(XrayVpnService.EXTRA_CONFIG, config)
                    putExtra(XrayVpnService.EXTRA_REMARK, remark)
                }

                try {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        act.startForegroundService(intent)
                    } else {
                        act.startService(intent)
                    }
                    durationSeconds = 0
                    startStatsTimer()
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start VPN service", e)
                    result.error("START_FAILED", e.message, null)
                }
            }

            "stopVpn" -> {
                stopStatsTimer()
                val act = activity
                if (act != null) {
                    val intent = Intent(act, XrayVpnService::class.java)
                    act.stopService(intent)
                }
                // Also try to stop via bridge directly
                try { XrayNativeBridge.stopLoop() } catch (_: Exception) {}
                durationSeconds = 0
                eventSink?.success(mapOf(
                    "state" to "DISCONNECTED",
                    "duration" to 0,
                    "uplinkSpeed" to 0,
                    "downlinkSpeed" to 0,
                    "uplinkTotal" to 0,
                    "downlinkTotal" to 0
                ))
                result.success(null)
            }

            "isRunning" -> {
                result.success(XrayNativeBridge.isRunning())
            }

            "measureDelay" -> {
                val config = call.argument<String>("config")
                val url = call.argument<String>("url") ?: "https://www.google.com/generate_204"
                if (config.isNullOrEmpty()) {
                    result.success(-1)
                    return
                }
                // Run on background thread
                Thread {
                    val delay = XrayNativeBridge.measureOutboundDelay(config, url)
                    mainHandler.post { result.success(delay.toInt()) }
                }.start()
            }

            "getCoreVersion" -> {
                result.success(XrayNativeBridge.getVersion())
            }

            "requestVpnPermission" -> {
                val act = activity
                if (act == null) {
                    result.success(false)
                    return
                }
                val vpnIntent = VpnService.prepare(act)
                if (vpnIntent == null) {
                    result.success(true) // Already granted
                } else {
                    act.startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
                    result.success(true) // Will be granted after user accepts
                }
            }

            else -> result.notImplemented()
        }
    }

    // EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopStatsTimer()
    }

    private fun startStatsTimer() {
        stopStatsTimer()
        statsTimer = Handler(Looper.getMainLooper())
        statsTimer?.postDelayed(object : Runnable {
            override fun run() {
                if (!XrayNativeBridge.isRunning()) return
                durationSeconds++
                // Query traffic stats from Xray
                val upTotal = XrayNativeBridge.queryStats("proxy", "uplink")
                val downTotal = XrayNativeBridge.queryStats("proxy", "downlink")
                eventSink?.success(mapOf(
                    "state" to "CONNECTED",
                    "duration" to durationSeconds,
                    "uplinkSpeed" to 0, // TODO: calculate delta
                    "downlinkSpeed" to 0,
                    "uplinkTotal" to upTotal,
                    "downlinkTotal" to downTotal
                ))
                statsTimer?.postDelayed(this, 1000)
            }
        }, 1000)
    }

    private fun stopStatsTimer() {
        statsTimer?.removeCallbacksAndMessages(null)
        statsTimer = null
    }
}
