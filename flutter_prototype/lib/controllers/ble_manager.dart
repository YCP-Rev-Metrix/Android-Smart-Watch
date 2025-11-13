import '../models/session.dart';

class BLEManager {
  bool isConnected = false;

  Future<void> connect(String deviceId) async {}
  Future<void> disconnect() async {}
  Future<void> sendSession(GameSession session) async {}
  void receiveAck(int packetId) {}
}