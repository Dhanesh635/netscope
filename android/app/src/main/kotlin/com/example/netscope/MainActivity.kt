package com.example.netscope

import android.util.Log
import com.example.netscope.network.NetworkService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val networkChannelName = "netscope/network"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		Log.d("MainActivity", "Registering MethodChannel: $networkChannelName")

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, networkChannelName)
			.setMethodCallHandler { call, result ->
				Log.d("MainActivity", "MethodChannel call received: ${call.method}")
				when (call.method) {
					"getCurrentSignalInfo" -> {
						val networkService = NetworkService(this)
						val info = networkService.getCurrentSignalInfo()
						val map = info.toMap()
						Log.d("MainActivity", "Returning signal info map: $map")
						result.success(map)
					}

					else -> result.notImplemented()
				}
			}
	}
}
