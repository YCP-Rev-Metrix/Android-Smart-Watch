package com.example.watch_app

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
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

    // --- Advertise Callback ---
    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            Log.i(TAG, "Advertise start success")
            mainHandler.post {
                channel.invokeMethod("onAdvertisingStarted", null)
            }
        }

        override fun onStartFailure(errorCode: Int) {
            Log.e(TAG, "Advertise failed: $errorCode")
            mainHandler.post {
                channel.invokeMethod("onAdvertisingFailed", errorCode)
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
                channel.invokeMethod("onConnectionStateChange", args)
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
                    channel.invokeMethod("onCharacteristicWrite", args)
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
}
