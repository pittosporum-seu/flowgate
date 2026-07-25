package com.v2ray.ang.enums

import androidx.annotation.StringRes
import com.v2ray.ang.R

enum class FlowSubscriptionUpdateMode(
    val value: String,
    @StringRes val titleRes: Int,
    @StringRes val summaryRes: Int,
) {
    AUTO("auto", R.string.flow_subscription_update_auto, R.string.flow_subscription_update_auto_summary),
    DIRECT("direct", R.string.flow_subscription_update_direct, R.string.flow_subscription_update_direct_summary),
    CURRENT_PROXY("current_proxy", R.string.flow_subscription_update_proxy, R.string.flow_subscription_update_proxy_summary);

    companion object {
        fun fromValue(value: String?): FlowSubscriptionUpdateMode {
            return entries.firstOrNull { it.value == value } ?: AUTO
        }
    }
}
