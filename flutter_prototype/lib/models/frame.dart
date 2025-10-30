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

  void addShot(Shot shot) {}
  Map<String, dynamic> toJson() => {};
  static Frame fromJson(Map<String, dynamic> json) => Frame(frameNumber: 0);
}
