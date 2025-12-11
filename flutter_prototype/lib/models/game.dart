// models/game.dart

import 'frame.dart';

class Game {
  final int gameNumber;
  int score;
  int startingLane;
  List<int> lanes;
  List<Frame> frames;

  Game({
    required this.gameNumber,
    this.score = 0,
    this.startingLane = 1,
    this.lanes = const [],
    required this.frames,
  });

  factory Game.newGame(int gameNumber, {int startingLane = 1}) {
    return Game(
      gameNumber: gameNumber,
      startingLane: startingLane,
      lanes: [startingLane],
      frames: List.generate(
        12,
        (i) => Frame(frameNumber: i + 1, lane: startingLane),
      ),
    );
  }

  // Finds the first frame where the 'shots' list is empty.
  Frame? get currentFrame =>
      frames.firstWhere((f) => f.shots.isEmpty, orElse: () => frames.last);

  // The game is complete if ALL frames are marked as 'isComplete'
  bool get isComplete => frames.every((f) => f.isComplete);

  Map<String, dynamic> toJson() => {
    'gameNumber': gameNumber,
    'score': score,
    'startingLane': startingLane,
    'lanes': lanes,
    'frames': frames.map((f) => f.toJson()).toList(),
  };

  static Game fromJson(Map<String, dynamic> json) => Game(
    gameNumber: json['gameNumber'] ?? 0,
    score: json['score'] ?? 0,
    startingLane: json['startingLane'] ?? 1,
    lanes: List<int>.from(json['lanes'] ?? []),
    frames: (json['frames'] as List<dynamic>?)
        ?.map((f) => Frame.fromJson(f))
        .toList() ??
        [],
  );
}