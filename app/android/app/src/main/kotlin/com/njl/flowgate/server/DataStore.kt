package com.njl.flowgate.server

import android.content.Context
import android.content.SharedPreferences
import com.njl.flowgate.server.dto.NodeDto
import com.njl.flowgate.server.dto.RoutingRulesDto
import com.njl.flowgate.server.dto.SubscriptionDto
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * SharedPreferences-based JSON persistence for FlowGate data.
 *
 * Stores nodes, subscriptions, and routing rules as JSON strings.
 * All operations are synchronous on the calling thread (Ktor CIO worker).
 */
class DataStore(context: Context) {

    companion object {
        private const val PREFS_NAME = "flowgate_data"
        private const val KEY_NODES = "nodes_json"
        private const val KEY_SUBSCRIPTIONS = "subscriptions_json"
        private const val KEY_ROUTING = "routing_json"
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    // ─── Nodes ────────────────────────────────────────────────────────────

    fun loadNodes(): MutableList<NodeDto> {
        val raw = prefs.getString(KEY_NODES, null) ?: return mutableListOf()
        return try {
            json.decodeFromString<List<NodeDto>>(raw).toMutableList()
        } catch (e: Exception) {
            mutableListOf()
        }
    }

    fun saveNodes(nodes: List<NodeDto>) {
        prefs.edit().putString(KEY_NODES, json.encodeToString(nodes)).apply()
    }

    // ─── Subscriptions ────────────────────────────────────────────────────

    fun loadSubscriptions(): MutableList<SubscriptionDto> {
        val raw = prefs.getString(KEY_SUBSCRIPTIONS, null) ?: return mutableListOf()
        return try {
            json.decodeFromString<List<SubscriptionDto>>(raw).toMutableList()
        } catch (e: Exception) {
            mutableListOf()
        }
    }

    fun saveSubscriptions(subs: List<SubscriptionDto>) {
        prefs.edit().putString(KEY_SUBSCRIPTIONS, json.encodeToString(subs)).apply()
    }

    // ─── Routing Rules ────────────────────────────────────────────────────

    fun loadRouting(): RoutingRulesDto {
        val raw = prefs.getString(KEY_ROUTING, null) ?: return RoutingRulesDto.default()
        return try {
            json.decodeFromString<RoutingRulesDto>(raw)
        } catch (e: Exception) {
            RoutingRulesDto.default()
        }
    }

    fun saveRouting(rules: RoutingRulesDto) {
        prefs.edit().putString(KEY_ROUTING, json.encodeToString(rules)).apply()
    }
}
