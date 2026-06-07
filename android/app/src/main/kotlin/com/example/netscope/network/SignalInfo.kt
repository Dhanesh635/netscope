package com.example.netscope.network

enum class SignalInfoStatus {
    AVAILABLE,
    PERMISSION_DENIED,
    UNSUPPORTED,
    UNAVAILABLE,
    ERROR,
}

enum class SignalTechnology {
    UNKNOWN,
    LTE,
    NR,
}

data class SignalInfo(
    val status: SignalInfoStatus,
    val technology: SignalTechnology = SignalTechnology.UNKNOWN,
    val rsrp: Int? = null,
    val rsrq: Int? = null,
    val sinr: Double? = null,
    val pci: Int? = null,
    val carrier: String? = null,
    val message: String? = null,
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "status" to status.name.lowercase(),
            "technology" to technology.name.lowercase(),
            "rsrp" to rsrp,
            "rsrq" to rsrq,
            "sinr" to sinr,
            "pci" to pci,
            "carrier" to carrier,
            "message" to message,
        )
    }

    companion object {
        fun available(
            technology: SignalTechnology,
            rsrp: Int?,
            rsrq: Int?,
            sinr: Double?,
            pci: Int?,
            carrier: String? = null,
            message: String? = null,
        ): SignalInfo {
            return SignalInfo(
                status = SignalInfoStatus.AVAILABLE,
                technology = technology,
                rsrp = rsrp,
                rsrq = rsrq,
                sinr = sinr,
                pci = pci,
                carrier = carrier,
                message = message,
            )
        }

        fun permissionDenied(message: String? = null): SignalInfo {
            return SignalInfo(
                status = SignalInfoStatus.PERMISSION_DENIED,
                message = message,
            )
        }

        fun unsupported(message: String? = null): SignalInfo {
            return SignalInfo(
                status = SignalInfoStatus.UNSUPPORTED,
                message = message,
            )
        }

        fun unavailable(message: String? = null): SignalInfo {
            return SignalInfo(
                status = SignalInfoStatus.UNAVAILABLE,
                message = message,
            )
        }

        fun error(message: String? = null): SignalInfo {
            return SignalInfo(
                status = SignalInfoStatus.ERROR,
                message = message,
            )
        }
    }
}
