package com.njl.flowgate

import android.os.Bundle
import android.util.Log
import com.njl.flowgate.server.DefaultVpnStateProvider
import com.njl.flowgate.server.FlowGateServer
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        /** Singleton server instance, accessible from Flutter plugin via context */
        var server: FlowGateServer? = null
            private set
        var stateProvider: DefaultVpnStateProvider? = null
            private set
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize and start the local REST API server
        val provider = DefaultVpnStateProvider(applicationContext, server?.logBuffer ?: com.njl.flowgate.server.LogBuffer())
        stateProvider = provider
        provider.register()

        val srv = FlowGateServer(applicationContext, provider)
        server = srv
        srv.start()

        Log.i(TAG, "FlowGate API server initialized on port ${srv.getPort()}")
    }

    override fun onDestroy() {
        super.onDestroy()
        // Don't stop server here - it should survive Activity recreation
        // Server lifecycle is tied to Application, not Activity
        Log.i(TAG, "MainActivity destroyed, server keeps running")
    }
}
