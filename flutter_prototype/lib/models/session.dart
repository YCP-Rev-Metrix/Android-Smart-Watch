import 'game.dart';

class GameSession {
  final String sessionId;
  final DateTime startTime;
  DateTime? endTime;
  bool isComplete;
  int numOfGames;
  List<String> balls;
  List<Game> games;

  GameSession({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    this.isComplete = false,
    this.numOfGames = 1,
    this.balls = const [],
    this.games = const [],
  });

  /// Returns the active game (first incomplete)
  Game? get activeGame {
    if (games.isEmpty) return null;
    return games.firstWhere(
      (g) => !g.isComplete,
      orElse: () => games.last,
    );
  }

  /// Marks the session complete and stamps end time
  void completeSession() {
    isComplete = true;
    endTime = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'isComplete': isComplete,
        'numOfGames': numOfGames,
        'balls': balls,
        'games': games.map((g) => g.toJson()).toList(),
      };

  static GameSession fromJson(Map<String, dynamic> json) => GameSession(
        sessionId: json['sessionId'] ?? '',
        startTime: DateTime.tryParse(json['startTime'] ?? '') ?? DateTime.now(),
        endTime: json['endTime'] != null
            ? DateTime.tryParse(json['endTime'])
            : null,
        isComplete: json['isComplete'] ?? false,
        numOfGames: json['numOfGames'] ?? 1,
        balls: List<String>.from(json['balls'] ?? []),
        games: (json['games'] as List<dynamic>?)
                ?.map((g) => Game.fromJson(g))
                .toList() ??
            [],
      );
}
