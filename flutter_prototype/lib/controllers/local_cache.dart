import '../models/session.dart';

class LocalCache {
  


  void saveSession(GameSession session) {}
  GameSession? loadLastSession() => null;
  List<GameSession> loadAllUnsent() => [];
  void markAllSent() {}
  void clearCache() {}
}
