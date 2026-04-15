// controllers/packet_queue.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'ble_manager.dart'; // To access BleGattManagerConstants

class PacketQueue {
  PacketQueue._internal();

  static final PacketQueue instance = PacketQueue._internal();
  static const _channel = MethodChannel('ble_service_channel');

  final Queue<List<int>> _queue = Queue<List<int>>();
  bool _isQueueProcessing = false;
  Completer<bool>? _indicationCompleter;

  // Called manually from BLEManager's _handleNativeCalls when 'onIndicationComplete' fires
  void handleNativeIndicationComplete(MethodCall call) {
    if (call.method == 'onIndicationComplete') {
      final args = call.arguments as Map<dynamic, dynamic>?;
      final success = args?['success'] as bool? ?? false;
      if (_indicationCompleter != null && !_indicationCompleter!.isCompleted) {
        _indicationCompleter!.complete(success);
      }
    }
  }

  /// Adds a packet to the back of the queue (FCFS enqueue) and starts processing.
  void enqueue(List<int> packet) {
    _queue.addLast(packet);
    // ignore: avoid_print
    print('[PacketQueue] Enqueued packet of size ${packet.length}. '
        'Queue length: ${_queue.length}');
        
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isQueueProcessing) return;
    _isQueueProcessing = true;

    try {
      while (_queue.isNotEmpty) {
        // peek at the front packet
        final packet = _queue.first;

        try {
          _indicationCompleter = Completer<bool>();

          // Attempt to send via the original BLE service channel
          await _channel.invokeMethod('sendNotification', {
            'serviceUuid': BleGattManagerConstants.serviceUuid,
            'charUuid': BleGattManagerConstants.notifyUuid,
            'bytes': packet,
          });
          
          // Wait for hardware ACK from Kotlin via onIndicationComplete
          final ackReceived = await _indicationCompleter!.future;
          
          if (ackReceived) {
            print('[PacketQueue] sent ${packet.length} bytes successfully and ACKed');
            
            // Confirmation successful, dequeue it
            dequeue();
            
            // Small delay before next packet to avoid swamping BLE buffer
            await Future.delayed(const Duration(milliseconds: 50));
          } else {
            print('[PacketQueue] Send failed (no ACK) or errored natively');
            // Wait before retrying the exact same packet
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          print('[PacketQueue] send error: $e');
          // Send failed - wait before retrying the same packet
          await Future.delayed(const Duration(milliseconds: 500));
        } finally {
          _indicationCompleter = null;
        }
      }
    } finally {
      _isQueueProcessing = false;
    }
  }

  /// Removes and returns the packet at the front of the queue, or null if empty.
  List<int>? dequeue() {
    if (_queue.isEmpty) return null;
    return _queue.removeFirst();
  }

  /// Returns the packet at the front without removing it, or null if empty.
  List<int>? peek() => _queue.isNotEmpty ? _queue.first : null;

  /// Current number of packets waiting in the queue.
  int get length => _queue.length;

  /// Whether the queue has no pending packets.
  bool get isEmpty => _queue.isEmpty;
}
