package com.v2ray.ang.dto.entities

data class ServerAffiliationInfo(
    var testDelayMillis: Long = 0L,
    var downloadBps: Long = 0L,
    var downloadTestAt: Long = 0L,
    var benchmarkState: String? = null,
) {
    fun getTestDelayString(): String {
        if (testDelayMillis == 0L) {
            return ""
        }
        return testDelayMillis.toString() + "ms"
    }

    fun getDownloadSpeedString(): String {
        if (downloadBps <= 0L) {
            return ""
        }
        val mbps = downloadBps * 8.0 / 1_000_000.0
        return if (mbps >= 10) {
            String.format("%.0f Mbps", mbps)
        } else {
            String.format("%.1f Mbps", mbps)
        }
    }
}
