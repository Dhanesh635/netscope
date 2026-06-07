package com.example.netscope.network

import android.telephony.CellInfo
import android.telephony.CellInfoNr
import android.telephony.CellIdentityNr
import android.telephony.CellSignalStrengthNr

class NrSignalExtractor : CellularSignalExtractor {
    override fun supports(cellInfo: CellInfo): Boolean {
        return cellInfo is CellInfoNr
    }

    override fun extract(cellInfo: CellInfo): SignalInfo {
        val nrCellInfo = cellInfo as CellInfoNr
        val signalStrength = nrCellInfo.cellSignalStrength as CellSignalStrengthNr
        val cellIdentity = nrCellInfo.cellIdentity as CellIdentityNr

        val rsrp: Int? = signalStrength.ssRsrp.let { if (it != CellInfo.UNAVAILABLE && it != Int.MAX_VALUE) it else null }
        val rsrq: Int? = signalStrength.ssRsrq.let { if (it != CellInfo.UNAVAILABLE && it != Int.MAX_VALUE) it else null }
        val sinr: Double? = signalStrength.ssSinr.let { if (it != CellInfo.UNAVAILABLE && it != Int.MAX_VALUE) it.toDouble() else null }
        val pci: Int? = cellIdentity.pci.let { if (it != CellInfo.UNAVAILABLE && it != Int.MAX_VALUE) it else null }

        return SignalInfo.available(
            technology = SignalTechnology.NR,
            rsrp = rsrp,
            rsrq = rsrq,
            sinr = sinr,
            pci = pci,
            carrier = null,
            message = if (nrCellInfo.isRegistered) "Serving 5G NR cell" else "Neighbor 5G NR cell"
        )
    }
}
