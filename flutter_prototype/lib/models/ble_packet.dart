import 'session.dart';

class BLEPacket {
  final int packetId;
  final String sessionJson;
  final List<int> encodedData;

  BLEPacket({
    required this.packetId,
    required this.sessionJson,
    required this.encodedData,
  });

  static BLEPacket buildFromSession(GameSession session) =>
      BLEPacket(packetId: 0, sessionJson: '', encodedData: []);
  List<int> encode() => [];
  static BLEPacket decode(List<int> data) =>
      BLEPacket(packetId: 0, sessionJson: '', encodedData: []);
}
