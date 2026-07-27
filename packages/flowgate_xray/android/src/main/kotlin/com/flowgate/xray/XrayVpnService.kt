package com.flowgate.xray

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import libv2ray.CoreCallbackHandler

/**
 * VpnService that runs Xray-core in-process via JNI (libv2ray).
 * Unlike flutter_vless which spawns libxray.so as a subprocess,
 * Xray runs inside this service's process, protected by startForeground().
 * This prevents Android LMK from killing the Xray core.
 */
class XrayVpnService : VpnService() {
    companion object {
        private const val TAG = "XrayVpnService"
        private const val CHANNEL_ID = "flowgate_xray_vpn"
        private const val NOTIFICATION_ID = 1
        const val EXTRA_CONFIG = "config"
        const val EXTRA_REMARK = "remark"

        var statusCallback: ((String, Int, Long, Long, Long, Long) -> Unit)? = null
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false

    private val coreCallback = object : CoreCallbackHandler {
        override fun startup(): Long = 0
        override fun shutdown(): Long {
            Log.w(TAG, "Core callback: shutdown")
            stopAllService()
            return 0
        }
        override fun onEmitStatus(l: Long, s: String?): Long = 0
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "Service created")
        createNotificationChannel()
        XrayNativeBridge.init(this, coreCallback)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand")
        val config = intent?.getStringExtra(EXTRA_CONFIG)
        val remark = intent?.getStringExtra(EXTRA_REMARK) ?: "FlowGate"

        if (config.isNullOrEmpty()) {
            Log.e(TAG, "No config provided")
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, buildNotification(remark))

        if (!setupVpn(config)) {
            Log.e(TAG, "VPN setup failed")
            stopSelf()
            return START_NOT_STICKY
        }

        return START_STICKY
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN permission revoked")
        stopAllService()
    }

    override fun onDestroy() {
        Log.i(TAG, "Service destroyed")
        if (isRunning) {
            closeVpnInterface()
        }
        super.onDestroy()
    }

    private fun setupVpn(config: String): Boolean {
        try {
            val builder = Builder()
                .setSession("FlowGate")
                .setMtu(1500)
                .addAddress("26.26.26.1", 30)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("1.1.1.1")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            // Exclude our own app from VPN to avoid routing loop
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to exclude self from VPN", e)
            }

            // Close old interface if any
            closeVpnInterface()

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish VPN interface")
                return false
            }
            isRunning = true

            // Start Xray core in-process with TUN fd
            val tunFd = vpnInterface!!.fd
            Log.i(TAG, "Starting Xray core loop with TUN fd=$tunFd")
            XrayNativeBridge.startLoop(config, tunFd)

            if (!XrayNativeBridge.isRunning()) {
                Log.e(TAG, "Xray core failed to start")
                stopAllService()
                return false
            }

            Log.i(TAG, "Xray core started successfully in-process")
            statusCallback?.invoke("CONNECTED", 0, 0, 0, 0, 0)
            return true

        } catch (e: Exception) {
            Log.e(TAG, "VPN setup error", e)
            return false
        }
    }

    fun stopAllService() {
        Log.i(TAG, "stopAllService")
        isRunning = false
        statusCallback?.invoke("DISCONNECTED", 0, 0, 0, 0, 0)

        try {
            XrayNativeBridge.stopLoop()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Xray loop", e)
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
        closeVpnInterface()
        stopSelf()
    }

    private fun closeVpnInterface() {
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            Log.w(TAG, "Error closing VPN interface", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "FlowGate VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(remark: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("FlowGate")
            .setContentText("Connected: $remark")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
