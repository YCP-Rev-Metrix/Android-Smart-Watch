import 'dart:convert';
import 'session.dart';
class BLEPacket {
  static const int PACKET_SIZE = 23;
  static const int HEADER_SIZE = 5;
  static const int DATA_SIZE = PACKET_SIZE - HEADER_SIZE; // 18 bytes
  
  static const int PACKET_TYPE_DATA = 0x01;
  static const int PACKET_TYPE_END = 0x02;

  final int packetType; // 0x01 = data, 0x02 = end marker
  final int totalPackets; // Total number of packets in the sequence
  final int packetIndex; // 0-based index of this packet
  final List<int> payload; // Data payload (up to 18 bytes)

  BLEPacket({
    required this.packetType,
    required this.totalPackets,
    required this.packetIndex,
    required this.payload,
  });
  /// Encodes the packet into a 23-byte array for BLE transmission.
  List<int> encode() {
    final buffer = List<int>.filled(PACKET_SIZE, 0);
    
    buffer[0] = packetType;
    buffer[1] = (totalPackets >> 8) & 0xFF;
    buffer[2] = totalPackets & 0xFF;
    buffer[3] = (packetIndex >> 8) & 0xFF;
    buffer[4] = packetIndex & 0xFF;
    
    // Copy payload into the buffer
    for (int i = 0; i < payload.length && i < DATA_SIZE; i++) {
      buffer[HEADER_SIZE + i] = payload[i];
    }
    
    return buffer;
  }

  /// Decodes a 23-byte packet from BLE data.
  static BLEPacket decode(List<int> data) {
    if (data.length < HEADER_SIZE) {
      throw ArgumentError('Packet too small: ${data.length} bytes');
    }

    final packetType = data[0];
    final totalPackets = (data[1] << 8) | data[2];
    final packetIndex = (data[3] << 8) | data[4];
    
    final payload = <int>[];
    for (int i = HEADER_SIZE; i < data.length; i++) {
      payload.add(data[i]);
    }
    
    return BLEPacket(
      packetType: packetType,
      totalPackets: totalPackets,
      packetIndex: packetIndex,
      payload: payload,
    );
  }

  /// Creates packets from a GameSession JSON, chunking into 18-byte payloads.
  static List<BLEPacket> buildFromSession(GameSession session) {
    // Convert session to JSON string
    final jsonString = jsonEncode(session.toJson());
    final jsonBytes = utf8.encode(jsonString);
    
    // Split JSON into 18-byte chunks
    final packets = <BLEPacket>[];
    final totalChunks = (jsonBytes.length + DATA_SIZE - 1) ~/ DATA_SIZE;
    
    for (int i = 0; i < jsonBytes.length; i += DATA_SIZE) {
      final end = (i + DATA_SIZE <= jsonBytes.length) 
          ? i + DATA_SIZE 
          : jsonBytes.length;
      
      final chunk = jsonBytes.sublist(i, end);
      final packetIndex = packets.length;
      
      packets.add(BLEPacket(
        packetType: PACKET_TYPE_DATA,
        totalPackets: totalChunks,
        packetIndex: packetIndex,
        payload: chunk,
      ));
    }
    
    // Append an end-marker packet to signal completion
    packets.add(BLEPacket(
      packetType: PACKET_TYPE_END,
      totalPackets: totalChunks + 1,
      packetIndex: totalChunks,
      payload: [],
    ));
    
    return packets;
  }
}
