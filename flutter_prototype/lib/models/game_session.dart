import 'frame.dart';

class GameSession {
  final String sessionId;
  final DateTime startTime;
  DateTime? endTime;
  bool isComplete;
  List<Frame> frames;

  GameSession({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    this.isComplete = false,
    this.frames = const [],
  });

  Map<String, dynamic> toJson() => {};
  static GameSession fromJson(Map<String, dynamic> json) => GameSession(
        sessionId: '',
        startTime: DateTime.now(),
      );
}
