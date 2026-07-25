package com.v2ray.ang.enums

enum class ConnectionState(val value: String) {
    OFF("off"),
    NO_NODE("no_node"),
    PREPARING("preparing"),
    REQUESTING_PERMISSION("requesting_permission"),
    CONNECTING("connecting"),
    CONNECTED("connected"),
    RECONFIGURING("reconfiguring"),
    DISCONNECTING("disconnecting"),
    ERROR("error"),
    SYSTEM_MANAGED("system_managed");

    companion object {
        fun fromValue(value: String?): ConnectionState {
            return entries.firstOrNull { it.value == value } ?: OFF
        }
    }
}
