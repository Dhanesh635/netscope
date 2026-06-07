package com.example.netscope.network

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.telephony.CellInfo
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat

class NetworkService(private val context: Context) {
    companion object {
        private const val TAG = "NetworkService"
    }

    private val telephonyManager: TelephonyManager? =
        context.getSystemService(TelephonyManager::class.java)
            ?: context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

    private val extractors: List<CellularSignalExtractor> = listOf(
        NrSignalExtractor(),
        LteSignalExtractor(),
    )

    fun getCurrentSignalInfo(): SignalInfo {
        Log.d(TAG, "getCurrentSignalInfo() called")

        if (!hasRequiredPermissions()) {
            Log.w(TAG, "Missing required permissions (READ_PHONE_STATE or ACCESS_FINE_LOCATION)")
            return SignalInfo.permissionDenied("Missing telephony permissions.")
        }

        val manager = telephonyManager
        if (manager == null) {
            Log.w(TAG, "TelephonyManager is null")
            return SignalInfo.unavailable("Telephony manager is not available.")
        }

        return try {
            val allCells = manager.allCellInfo
            Log.d(TAG, "allCellInfo returned ${allCells?.size ?: 0} cells")
            allCells?.forEachIndexed { index, cell ->
                Log.d(TAG, "  Cell[$index]: type=${cell.javaClass.simpleName}, registered=${cell.isRegistered}")
            }

            val cellInfo = selectBestCellInfo(allCells)
            if (cellInfo == null) {
                Log.w(TAG, "No supported cell found among ${allCells?.size ?: 0} cells")
                return SignalInfo.unavailable("No supported cellular signal is available.")
            }

            Log.d(TAG, "Selected cell: type=${cellInfo.javaClass.simpleName}, registered=${cellInfo.isRegistered}")

            val signalInfo = extractors.firstOrNull { it.supports(cellInfo) }?.extract(cellInfo)
            if (signalInfo == null) {
                Log.w(TAG, "No extractor could handle ${cellInfo.javaClass.simpleName}")
                return SignalInfo.unsupported("Supported cellular technology is not implemented yet.")
            }

            Log.d(TAG, "Extracted signal: rsrp=${signalInfo.rsrp}, rsrq=${signalInfo.rsrq}, sinr=${signalInfo.sinr}, pci=${signalInfo.pci}")

            // Enrich with carrier name if available
            val carrierName: String? = try {
                manager.networkOperatorName
            } catch (t: Throwable) {
                null
            }
            Log.d(TAG, "Carrier name from TelephonyManager: '$carrierName'")

            val result = if (signalInfo.carrier == null && carrierName != null && carrierName.isNotEmpty()) {
                signalInfo.copy(carrier = carrierName)
            } else {
                signalInfo
            }

            Log.d(TAG, "Final SignalInfo: ${result.toMap()}")
            result
        } catch (t: Throwable) {
            Log.e(TAG, "Exception in getCurrentSignalInfo", t)
            SignalInfo.error(t.message)
        }
    }

    private fun selectBestCellInfo(cellInfos: List<CellInfo>?): CellInfo? {
        val supportedCells = cellInfos.orEmpty().filter { cellInfo ->
            extractors.any { extractor -> extractor.supports(cellInfo) }
        }
        Log.d(TAG, "selectBestCellInfo: ${supportedCells.size} supported out of ${cellInfos?.size ?: 0} total")

        return supportedCells.firstOrNull { it.isRegistered } ?: supportedCells.firstOrNull()
    }

    private fun hasRequiredPermissions(): Boolean {
        val hasPhoneStatePermission =
            ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) ==
                PackageManager.PERMISSION_GRANTED
        val hasLocationPermission =
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED

        Log.d(TAG, "Permissions: READ_PHONE_STATE=$hasPhoneStatePermission, ACCESS_FINE_LOCATION=$hasLocationPermission")
        return hasPhoneStatePermission && hasLocationPermission
    }
}
