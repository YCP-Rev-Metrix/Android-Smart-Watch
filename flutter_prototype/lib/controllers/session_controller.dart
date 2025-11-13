import '../models/session.dart';
import 'local_cache.dart';
import 'ble_manager.dart';

class SessionController {
  final LocalCache cache;
  final BLEManager ble;

  SessionController(this.cache, this.ble);

  GameSession? currentSession;

  void startNewSession() {}
  void endCurrentSession() {}

  void recordShot({
    required int frameIndex,
    required int shotNumber,
    required List<bool> pins,
    int ball = 1,
    int board = 18,
    int lane = 1,
    double ballSpeed = 15.0,
    String? outcome,
  }) {}

  int getFrameScore(int frameIndex) => 0;
  int getTotalScore() => 0;
  Future<void> persistAndSend() async {}
}
