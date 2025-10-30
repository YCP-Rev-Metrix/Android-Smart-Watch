import '../models/game_session.dart';

class LocalCache {
  int id = 0;
  String sessionId = "";
  String payload = "";
  bool sent = false;
  DateTime timestamp = DateTime.now();

  void queueSession(GameSession session) {}
  void markAsSent() {}
  void saveSession(GameSession session) {}
  GameSession loadSession() => GameSession();
  void clearCache() {}
}