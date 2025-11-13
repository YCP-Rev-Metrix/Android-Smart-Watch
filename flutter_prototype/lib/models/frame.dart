import 'shot.dart';

class Frame {
  final int frameNumber;
  List<Shot> shots;
  bool isComplete;
  int score;

  Frame({
    required this.frameNumber,
    this.shots = const [],
    this.isComplete = false,
    this.score = 0,
  });

  /// Adds a shot to the frame, and marks complete if appropriate
  void addShot(Shot shot) {
    shots = [...shots, shot];
    if (frameNumber < 10) {
      // Normal frame (max 2 shots)
      isComplete = shots.length >= 2 || shot.pinCount == 10;
    } else {
      // 10th frame can have up to 3
      isComplete = shots.length >= 3;
    }
  }

  Map<String, dynamic> toJson() => {
        'frameNumber': frameNumber,
        'shots': shots.map((s) => s.toJson()).toList(),
        'isComplete': isComplete,
        'score': score,
      };

  static Frame fromJson(Map<String, dynamic> json) => Frame(
        frameNumber: json['frameNumber'] ?? 0,
        shots: (json['shots'] as List<dynamic>?)
                ?.map((s) => Shot.fromJson(s))
                .toList() ??
            [],
        isComplete: json['isComplete'] ?? false,
        score: json['score'] ?? 0,
      );
}
