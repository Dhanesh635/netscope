package com.example.netscope.network

import android.os.Build
import android.telephony.CellInfo
import android.telephony.CellInfoLte
import android.telephony.CellIdentityLte
import android.telephony.CellSignalStrengthLte
import android.util.Log

class LteSignalExtractor : CellularSignalExtractor {
    companion object {
        private const val TAG = "LteSignalExtractor"
    }

    override fun supports(cellInfo: CellInfo): Boolean {
        return cellInfo is CellInfoLte
    }

    override fun extract(cellInfo: CellInfo): SignalInfo {
        val lteCellInfo = cellInfo as CellInfoLte
        val signalStrength = lteCellInfo.cellSignalStrength as CellSignalStrengthLte
        val cellIdentity = lteCellInfo.cellIdentity as CellIdentityLte

        val rsrp: Int? = signalStrength.rsrp.let { if (it != CellInfo.UNAVAILABLE && it != Int.MAX_VALUE) it else null }
        val rsrq: Int? = signalStrength.rsrq.let { if (it != CellInfo.UNAVAILABLE && it != Int.MAX_VALUE) it else null }
        val pci: Int? = cellIdentity.pci.let { if (it != CellInfo.UNAVAILABLE && it != Int.MAX_VALUE) it else null }

        // Use true rssnr if available. Do not approximate.
        val sinr: Double? = signalStrength.rssnr.let {
            if (it != CellInfo.UNAVAILABLE && it != Int.MAX_VALUE && it != 0) it.toDouble() else null
        }

        Log.d(TAG, "Extracted LTE signal: rsrp=$rsrp, rsrq=$rsrq, sinr=$sinr, pci=$pci, registered=${lteCellInfo.isRegistered}")

        return SignalInfo.available(
            technology = SignalTechnology.LTE,
            rsrp = rsrp,
            rsrq = rsrq,
            sinr = sinr,
            pci = pci,
            carrier = null,
            message = if (lteCellInfo.isRegistered) "Serving LTE cell" else "Neighbor LTE cell"
        )
    }
}
