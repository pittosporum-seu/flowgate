package com.v2ray.ang.enums

import androidx.annotation.StringRes
import com.v2ray.ang.R

enum class RouteMode(
    val value: String,
    @StringRes val titleRes: Int,
    @StringRes val summaryRes: Int,
) {
    GLOBAL("global", R.string.flow_mode_global, R.string.flow_mode_global_summary),
    SMART("smart", R.string.flow_mode_smart, R.string.flow_mode_smart_summary),
    BLOCK_CN("block_cn", R.string.flow_mode_block_cn, R.string.flow_mode_block_cn_summary),
    CUSTOM("custom", R.string.flow_mode_custom, R.string.flow_mode_custom_summary);

    companion object {
        fun fromValue(value: String?): RouteMode {
            return when (value) {
                "smart_cn", "ai_google" -> SMART
                else -> entries.firstOrNull { it.value == value } ?: SMART
            }
        }
    }
}
