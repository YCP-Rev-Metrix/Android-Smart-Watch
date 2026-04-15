package com.example.watch_app

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.app.PendingIntent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.Manifest
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodChannel
import java.util.*

class BleGattManager(private val context: Context, private val channel: MethodChannel) {

    companion object {
        private const val TAG = "BleGattManager"

        val SERVICE_UUID: UUID = UUID.fromString("a3c94f10-7b47-4c8e-b88f-0e4b2f7c2a91")
        val COMMAND_UUID: UUID = UUID.fromString("a3c94f11-7b47-4c8e-b88f-0e4b2f7c2a91")
        val NOTIFY_UUID: UUID  = UUID.fromString("a3c94f12-7b47-4c8e-b88f-0e4b2f7c2a91")
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private var advertiser: BluetoothLeAdvertiser? = bluetoothAdapter?.bluetoothLeAdvertiser
    private var gattServer: BluetoothGattServer? = null
    private val connectedDevices = mutableSetOf<BluetoothDevice>()
    private val NOTIF_CHANNEL_ID = "watch_events_channel"
    private val NOTIF_CHANNEL_NAME = "Watch Events"
    private val notifManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var notifIdCounter = 1

    init {
        createNotificationChannelIfNeeded()
    }

    // --- Advertise Callback ---
    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            Log.i(TAG, "Advertise start success")
            mainHandler.post {
                if (!MainActivity.isFlutterAttached) {
                    Log.w(TAG, "Flutter not attached, skipping onAdvertisingStarted callback")
                    return@post
                }
                try {
                    channel.invokeMethod("onAdvertisingStarted", null)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to invoke Flutter method: ${e.message}")
                }
            }
        }

        override fun onStartFailure(errorCode: Int) {
            Log.e(TAG, "Advertise failed: $errorCode")
            mainHandler.post {
                if (!MainActivity.isFlutterAttached) {
                    Log.w(TAG, "Flutter not attached, skipping onAdvertisingFailed callback")
                    return@post
                }
                try {
                    channel.invokeMethod("onAdvertisingFailed", errorCode)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to invoke Flutter method: ${e.message}")
                }
            }
        }
    }

    // --- GATT Callback ---
    private val gattCallback = object : BluetoothGattServerCallback() {

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connectedDevices.add(device)
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                connectedDevices.remove(device)
            }

            val args = mapOf(
                "device" to device.address,
                "state" to newState
            )

            Log.i(TAG, "Device connected: ${device.address}")

            mainHandler.post {
                if (!MainActivity.isFlutterAttached) {
                    Log.w(TAG, "Flutter not attached, skipping onConnectionStateChange callback")
                    return@post
                }
                try {
                    channel.invokeMethod("onConnectionStateChange", args)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to invoke Flutter method: ${e.message}")
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            Log.i(TAG, "Write request on ${characteristic.uuid} from ${device.address}")

            if (characteristic.uuid == COMMAND_UUID) {

                val args = mapOf(
                    "device" to device.address,
                    "uuid" to characteristic.uuid.toString(),
                    "value" to value
                )
                mainHandler.post {
                    if (!MainActivity.isFlutterAttached) {
                        Log.w(TAG, "Flutter not attached, skipping onCharacteristicWrite callback")
                        return@post
                    }
                    try {
                        channel.invokeMethod("onCharacteristicWrite", args)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to invoke Flutter method: ${e.message}")
                    }
                }

                    // Post a local notification for command writes
                    try {
                        val title = "Command received"
                        val body = "From ${device.address}: ${value.joinToString(separator = ",") { it.toString() }}"
                        showNotification(title, body)
                    } catch (e: Exception) {
                        Log.w(TAG, "Notification error: ${e.message}")
                    }
            }

            if (responseNeeded) {
                gattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    0,
                    null
                )
            }
        }
    }

    // --- Init GATT Server ---
    fun initGattServer() {
        if (gattServer != null) return

        Log.i(TAG, "Initializing GATT server…")

        gattServer = bluetoothManager.openGattServer(context, gattCallback)

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        val commandChar = BluetoothGattCharacteristic(
            COMMAND_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )

        val notifyChar = BluetoothGattCharacteristic(
            NOTIFY_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        service.addCharacteristic(commandChar)
        service.addCharacteristic(notifyChar)

        gattServer?.addService(service)

        Log.i(TAG, "GATT service + characteristics added.")
    }

    // --- Advertising ---
    fun startAdvertising() {
        if (advertiser == null) {
            Log.e(TAG, "No advertiser available")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTimeout(0)
            .build()

        // Keep payload small
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        advertiser?.startAdvertising(settings, data, advertiseCallback)

        Log.i(TAG, "Advertising started (minimal mode)")
    }

    fun stopAdvertising() {
        advertiser?.stopAdvertising(advertiseCallback)
    }

    fun disconnectCurrentConnection() {
        try {
            for (device in connectedDevices) {
                gattServer?.cancelConnection(device)
            }
            Log.i(TAG, "Disconnected all connected devices")
        } catch (e: Exception) {
            Log.e(TAG, "disconnectCurrentConnection error: $e")
        }
    }

    // --- Send notification to phone ---
    fun sendNotification(serviceUuid: String, charUuid: String, bytes: ByteArray) {
        try {
            val svc = gattServer?.getService(UUID.fromString(serviceUuid)) ?: return
            val ch = svc.getCharacteristic(UUID.fromString(charUuid)) ?: return
            ch.value = bytes

            for (device in connectedDevices) {
                gattServer?.notifyCharacteristicChanged(device, ch, false)
            }

        } catch (e: Exception) {
            Log.e(TAG, "sendNotification error: $e")
        }
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val existing = notifManager.getNotificationChannel(NOTIF_CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    NOTIF_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_DEFAULT
                )
                channel.description = "Notifications for watch events"
                notifManager.createNotificationChannel(channel)
            }
        }
    }

    private fun showNotification(title: String, body: String) {
        // If Android 13+, ensure runtime permission is granted before posting
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                Log.w(TAG, "POST_NOTIFICATIONS permission not granted; skipping notification")
                return
            }
        }

        val intent = Intent(context, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val notif = NotificationCompat.Builder(context, NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val id = notifIdCounter++
        notifManager.notify(id, notif)
    }
}
