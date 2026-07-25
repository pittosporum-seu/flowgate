package com.v2ray.ang.enums

import androidx.annotation.StringRes
import com.v2ray.ang.R

enum class FlowRoutePack(
    val value: String,
    @StringRes val titleRes: Int,
) {
    SMART_CN("smart_cn", R.string.flow_rule_pack_smart_cn),
    SERVICE_ADAPTIVE("service_adaptive", R.string.flow_rule_pack_service_adaptive),
    BLOCK_CN("block_cn", R.string.flow_rule_pack_block_cn),
    GOOGLE_PLAY("google_play", R.string.flow_rule_pack_google_play),
    ADBLOCK("adblock", R.string.flow_rule_pack_adblock),
    STREAMING("streaming", R.string.flow_rule_pack_streaming),
    GLOBAL("global", R.string.flow_rule_pack_global),
    CUSTOM("custom", R.string.flow_rule_pack_custom);

    companion object {
        fun fromValue(value: String?): FlowRoutePack {
            return when (value) {
                "ai_google" -> SERVICE_ADAPTIVE
                else -> entries.firstOrNull { it.value == value } ?: SMART_CN
            }
        }
    }
}
