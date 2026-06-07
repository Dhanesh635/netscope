package com.example.netscope.network

import android.telephony.CellInfo

interface CellularSignalExtractor {
    fun supports(cellInfo: CellInfo): Boolean

    fun extract(cellInfo: CellInfo): SignalInfo
}
