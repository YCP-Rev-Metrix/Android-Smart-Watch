import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class BLEManager extends GetxController {
  var isAdvertising = false.obs;
  var gattReady = false.obs;

  static const _channel = MethodChannel('ble_service_channel');

  // Incoming command callback
  Rxn<Map<String, dynamic>> lastReceivedCommand = Rxn<Map<String, dynamic>>();
  var connectedDeviceAddress = ''.obs;
  var isConnected = false.obs;

  // Chunk reassembly fields
  final List<int> _incomingBuffer = [];
  DateTime? _lastChunkTime;

  BLEManager() {
    // Register native callback handler early so we receive native events
    _channel.setMethodCallHandler(_handleNativeCalls);
    _initLocalNotifications();
  }

  // --- Local notifications setup ---
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    try {
      await _localNotif.initialize(initSettings);

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'watch_events_channel', // id
        'Watch Events', // title
        description: 'Notifications for watch events',
        importance: Importance.defaultImportance,
      );

      await _localNotif
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      print('Local notifications init failed: $e');
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'watch_events_channel',
        'Watch Events',
        channelDescription: 'Notifications for watch events',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ticker: 'ticker',
      );

      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      await _localNotif.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, platformDetails);
    } catch (e) {
      print('Show notification failed: $e');
    }
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

          // Chunk reassembly logic
          final now = DateTime.now();
          
          // If more than 500ms since last chunk, start fresh
          if (_lastChunkTime != null && now.difference(_lastChunkTime!) > Duration(milliseconds: 500)) {
            print('WATCH BLE Timeout, clearing buffer');
            _incomingBuffer.clear();
          }
          _lastChunkTime = now;
          
          // Add chunk to buffer
          _incomingBuffer.addAll(bytes);
          print('WATCH BLE Chunk received (${bytes.length} bytes), buffer size: ${_incomingBuffer.length}');
          
          // Try to parse as JSON
          try {
            final raw = utf8.decode(_incomingBuffer);
            final parsed = json.decode(raw);
            
            // Success! We have complete JSON
            print('WATCH BLE RECEIVED COMPLETE: $raw');
            
            if (parsed is Map<String, dynamic>) {
              lastReceivedCommand.value = parsed;
              
              // Handle userData command
              if (parsed['cmd'] == 'userData') {
                print('WATCH BLE Username: ${parsed['username']}');
                print('WATCH BLE Hand: ${parsed['hand']}');
                print('WATCH BLE Sessions: ${parsed['sessions']}');
                print('WATCH BLE Balls: ${parsed['balls']}');
                
                // Store this data in your watch app state
              }
              
              await _showLocalNotification('Command received', 'Received ${parsed['cmd']}');
            } else {
              lastReceivedCommand.value = {'value': parsed};
            }
            
            // Clear buffer after successful parse
            _incomingBuffer.clear();
            _lastChunkTime = null;
            
          } catch (e) {
            // Not complete yet, wait for more chunks
            if (_incomingBuffer.length > 1000) {
              print('WATCH BLE Buffer too large, clearing');
              _incomingBuffer.clear();
              _lastChunkTime = null;
            }
          }
          break;

        // show local notification for connection changes from native (also handled below in onConnectionStateChange)

        case 'onConnectionStateChange':
          final args = call.arguments as Map<dynamic, dynamic>;
          final device = args['device'] as String? ?? '';
          final state = args['state'] as int? ?? 0;
          connectedDeviceAddress.value = device;
          isConnected.value = state == 2;
          update();

          // Show a user-friendly notification for connect/disconnect
          try {
            if (state == 2) {
              await _showLocalNotification('Bluetooth connected', 'Connected to mobile application');
            } else if (state == 0 || state == 1) {
              // treat 0/1 as disconnected for user messaging
              await _showLocalNotification('Bluetooth disconnected', 'Disconnected from mobile application');
            }
          } catch (e) {
            print('Notification error: $e');
          }
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
  
  Future<void> sendRawBLEPacket(List<int> bytes) async {
    try {
      await _channel.invokeMethod('sendNotification', {
        'serviceUuid': BleGattManagerConstants.serviceUuid,
        'charUuid': BleGattManagerConstants.notifyUuid,
        'bytes': bytes,
      });
      print('BLEManager.sendRawBLEPacket -> sent ${bytes.length} bytes');
    } catch (e) {
      print('sendRawBLEPacket error: $e');
      rethrow;
    }
  }

  /// Send a JSON object in small chunks via BLE, Each chunk is up to 20 bytes, sent one at a time with 50ms delay
  Future<void> sendJsonInChunks(Map<String, dynamic> jsonObj) async {
    try {
      final jsonString = json.encode(jsonObj);
      final bytes = utf8.encode(jsonString);
      
      print('BLEManager.sendJsonInChunks: Sending ${bytes.length} bytes in chunks');
      
      const chunkSize = 20; 
      final totalChunks = (bytes.length + chunkSize - 1) ~/ chunkSize;
      
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize <= bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        
        await sendRawBLEPacket(chunk);
        print('BLEManager: Sent chunk ${(i ~/ chunkSize) + 1}/$totalChunks (${chunk.length} bytes)');
        
        // Delay between chunks so phone can process
        if (i + chunkSize < bytes.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      print('BLEManager.sendJsonInChunks: Complete!');
    } catch (e) {
      print('sendJsonInChunks error: $e');
      rethrow;
    }
  }
  
  Future<void> sendRecordingCommand(String cmd) async {
  await sendJsonToPhone({"cmd": cmd});
  }
  Future<void> startRecording() async {
    await sendRecordingCommand("startRec");
  }

  Future<void> stopRecording() async {
    await sendRecordingCommand("stopRec");
  }

}

/// Small constants mirror for Dart side for the GATT service/characteristics
class BleGattManagerConstants {
  static const serviceUuid = 'a3c94f10-7b47-4c8e-b88f-0e4b2f7c2a91';
  static const commandUuid = 'a3c94f11-7b47-4c8e-b88f-0e4b2f7c2a91';
  static const notifyUuid = 'a3c94f12-7b47-4c8e-b88f-0e4b2f7c2a91';
}
