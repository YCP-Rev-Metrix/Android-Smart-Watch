package com.example.watch_app

import android.os.Bundle
import android.os.Build
import android.graphics.Rect
import android.view.WindowInsets
import android.view.WindowInsetsController
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity: FlutterActivity() {

    private val CHANNEL = "ble_service_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

            // Create a persistent MethodChannel used for BLE service and GATT operations
            val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

            // Instantiate our GATT manager which will callback into the MethodChannel
            val bleGattManager = BleGattManager(this, methodChannel)

            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, BleForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "initGattServer" -> {
                        bleGattManager.initGattServer()
                        result.success(null)
                    }
                    "startAdvertising" -> {
                        bleGattManager.startAdvertising()
                        result.success(null)
                    }
                    "stopAdvertising" -> {
                        bleGattManager.stopAdvertising()
                        result.success(null)
                    }
                    "sendNotification" -> {
                        val service = call.argument<String>("serviceUuid") ?: ""
                        val char = call.argument<String>("charUuid") ?: ""
                        val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                        bleGattManager.sendNotification(service, char, bytes)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Disable system gestures on Wear OS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)

            window.insetsController?.let {
                it.hide(WindowInsets.Type.systemGestures())
                it.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_BARS_BY_SWIPE
            }

            window.decorView.setOnApplyWindowInsetsListener { v, insets ->
                val exclusionRect = Rect(0, 0, v.width, v.height)
                v.systemGestureExclusionRects = listOf(exclusionRect)
                insets
            }
        }
    }
}
