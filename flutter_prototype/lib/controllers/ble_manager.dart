import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';


class BLEManager extends GetxController {
  var isAdvertising = false.obs;
  var gattReady = false.obs;

  static const _channel = MethodChannel('ble_service_channel');

  // Incoming command callback
  Rxn<Map<String, dynamic>> lastReceivedCommand = Rxn<Map<String, dynamic>>();
  var connectedDeviceAddress = ''.obs;
  var isConnected = false.obs;

  BLEManager() {
    // Register native callback handler early so we receive native events
    _channel.setMethodCallHandler(_handleNativeCalls);
  }

  Future<void> initGattServer() async {
    try {
      final ok = await _ensurePermissions();
      if (!ok) {
        print('initGattServer: required permissions not granted');
        return;
      }

      // Start the foreground service to keep BLE alive on Android
      await _ensureForegroundService();

      await _channel.invokeMethod('initGattServer');
    gattReady.value = true;

      print('BLEManager.initGattServer -> native init requested');
    } catch (e) {
      print('initGattServer error: $e');
    }
  }

  Future<dynamic> _handleNativeCalls(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onCharacteristicWrite':
          final args = call.arguments as Map<dynamic, dynamic>;
          final value = args['value'];
          Uint8List bytes;
          if (value is Uint8List) {
            bytes = value;
          } else if (value is List<int>) {
            bytes = Uint8List.fromList(List<int>.from(value));
          } else {
            return null;
          }

          final raw = utf8.decode(bytes);
          try {
            final parsed = json.decode(raw);
            if (parsed is Map<String, dynamic>) {
              lastReceivedCommand.value = parsed;
            } else {
              lastReceivedCommand.value = {'value': parsed};
            }
          } catch (e) {
            lastReceivedCommand.value = {'raw': raw};
          }
          break;

        case 'onConnectionStateChange':
          final args = call.arguments as Map<dynamic, dynamic>;
          final device = args['device'] as String? ?? '';
          final state = args['state'] as int? ?? 0;
          connectedDeviceAddress.value = device;
          isConnected.value = state == 2; 
          update();
          break;

        case 'onAdvertisingStarted':
         isAdvertising.value = true;
          update();
          break;

        case 'onAdvertisingFailed':
          isAdvertising.value = false;
          update();
          break;
      }
    } catch (e) {
      print('Error in native callback handler: $e');
    }
    return null;
  }

  Future<void> startAdvertising() async {
    try {
      final ok = await _ensurePermissions();
      if (!ok) {
        print('startAdvertising: permissions not granted');
        return;
      }

      // Ensure GATT server is initialized and foreground service is running
      if (!gattReady.value) {
        await initGattServer();
      }
      await _ensureForegroundService();

      await _channel.invokeMethod('startAdvertising');
  isAdvertising.value = true;
      update();
    } catch (e) {
      print('startAdvertising error: $e');
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _channel.invokeMethod('stopAdvertising');
  isAdvertising.value = false;
      update();
    } catch (e) {
      print('stopAdvertising error: $e');
    }
  }

  Future<void> sendJsonToPhone(Map<String, dynamic> jsonObj) async {
    try {
      final bytes = utf8.encode(json.encode(jsonObj));
      await _channel.invokeMethod('sendNotification', {
        'serviceUuid': BleGattManagerConstants.serviceUuid,
        'charUuid': BleGattManagerConstants.notifyUuid,
        'bytes': bytes,
      });
      print('BLEManager.sendJsonToPhone -> sent');
    } catch (e) {
      print('sendJsonToPhone error: $e');
    }
  }
  
  // Request runtime permissions required for BLE peripheral on Android.
  Future<bool> _ensurePermissions() async {
    // Only required on Android; on iOS permissions are handled differently
    if (!Platform.isAndroid) return true;

    try {
      final perms = <Permission>[];
      // Add Bluetooth permissions (Android 12+)
      perms.add(Permission.bluetoothScan);
      perms.add(Permission.bluetoothAdvertise);
      perms.add(Permission.bluetoothConnect);

      // Location is still required on some devices
      perms.add(Permission.location);

      final statuses = await perms.request();
      // Ensure all requested permissions are granted
      final allOk = statuses.values.every((s) => s.isGranted);
      return allOk;
    } catch (e) {
      print('Permission request failed: $e');
      return false;
    }
  }

  // Ensure the Android foreground service is started so BLE stays alive.
  Future<void> _ensureForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startService');
      print('Foreground BLE service requested');
    } catch (e) {
      print('Failed to start foreground service: $e');
    }
  }

}

/// Small constants mirror for Dart side for the GATT service/characteristics
class BleGattManagerConstants {
  static const serviceUuid = 'a3c94f10-7b47-4c8e-b88f-0e4b2f7c2a91';
  static const commandUuid = 'a3c94f11-7b47-4c8e-b88f-0e4b2f7c2a91';
  static const notifyUuid = 'a3c94f12-7b47-4c8e-b88f-0e4b2f7c2a91';
}
