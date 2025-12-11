import 'dart:async';
import 'package:get/get.dart';
import '../models/ble_packet.dart';
import '../models/session.dart';
import 'ble_manager.dart';

class BLEPacketController extends GetxController {
  final BLEManager bleManager = BLEManager();
  
  var isTransmitting = false.obs;
  var currentPacket = 0.obs;
  var totalPackets = 0.obs;
  var lastError = Rxn<String>();
  static const int PACKET_DELAY_MS = 50;
  Future<void> sendSessionOverBLE(GameSession session) async {
    if (isTransmitting.value) {
      lastError.value = 'Transmission already in progress';
      return;
    }
    
    try {
      isTransmitting.value = true;
      lastError.value = null;
      
      // Build packets from session
      final packets = BLEPacket.buildFromSession(session);
      totalPackets.value = packets.length;
      
      print('BLEPacketController: Starting transmission of ${packets.length} packets');
      
      for (int i = 0; i < packets.length; i++) {
        currentPacket.value = i + 1;
        final packet = packets[i];
        
        try {
          await _sendPacket(packet);
          print('BLEPacketController: Sent packet ${i + 1}/${packets.length}');
          
          // Add delay between packets to allow phone to process
          if (i < packets.length - 1) {
            await Future.delayed(Duration(milliseconds: PACKET_DELAY_MS));
          }
        } catch (e) {
          lastError.value = 'Failed to send packet ${i + 1}: $e';
          print('BLEPacketController: $lastError');
          rethrow;
        }
      }
      
      print('BLEPacketController: Transmission complete!');
    } catch (e) {
      lastError.value = 'Transmission failed: $e';
      print('BLEPacketController error: $lastError');
    } finally {
      isTransmitting.value = false;
    }
  }
  

  /// Converts the packet to a 23-byte array and sends it through the BLE notification characteristic
  Future<void> _sendPacket(BLEPacket packet) async {
    final encoded = packet.encode();
    
    // Send the packet using BLE manager's public method
    await bleManager.sendRawBLEPacket(encoded);
  }
  
  /// Utility: Gets the transmission progress as a percentage.
  double getProgressPercentage() {
    if (totalPackets.value == 0) return 0.0;
    return (currentPacket.value / totalPackets.value) * 100.0;
  }
  
  /// Utility: Gets a human-readable status message.
  String getStatusMessage() {
    if (!isTransmitting.value && lastError.value == null) {
      return 'Ready';
    }
    if (isTransmitting.value) {
      return 'Transmitting ${currentPacket.value}/${totalPackets.value}';
    }
    return lastError.value ?? 'Unknown error';
  }
}
