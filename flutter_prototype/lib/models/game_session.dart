import 'frame.dart';

class GameSession {
  String sessionId = "";
  DateTime startTime = DateTime.now();
  DateTime endTime = DateTime.now();
  String establishment = "";
  List<Frame> frames = [];
  bool isComplete = false;

  void startSession() {}
  void endSession() {}
  String toJSON() => "";
  static GameSession fromJSON(String json) => GameSession();
}