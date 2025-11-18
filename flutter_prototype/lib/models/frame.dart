// models/frame.dart
import 'shot.dart';

class Frame {
  final int frameNumber; // Frame # (1-12)
  int lane; // lane # for this frame/shot
  Shot? shot; // Only holds one shot object now

  Frame({
    required this.frameNumber,
    required this.lane,
    this.shot,
  });

  /// Checks if the frame is logically complete based on its number and shot.
  /// (Controller logic will ultimately determine completion for scoring)
  bool get isComplete => shot != null;

  Map<String, dynamic> toJson() => {
    'frameNumber': frameNumber,
    'lane': lane,
    'shot': shot?.toJson(),
  };

  static Frame fromJson(Map<String, dynamic> json) => Frame(
    frameNumber: json['frameNumber'] ?? 0,
    lane: json['lane'] ?? 1,
    shot: json['shot'] != null ? Shot.fromJson(json['shot']) : null,
  );
}