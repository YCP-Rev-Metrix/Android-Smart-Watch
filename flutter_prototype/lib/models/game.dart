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
    this.frames = const [],
  });

  Frame? get currentFrame =>
      frames.firstWhere((f) => !f.isComplete, orElse: () => frames.last);

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
