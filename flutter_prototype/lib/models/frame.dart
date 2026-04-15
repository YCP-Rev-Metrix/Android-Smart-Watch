// models/frame.dart

import 'shot.dart';

class Frame {
  final int frameNumber;
  int lane;
  final List<Shot> shots;

  Frame({
    required this.frameNumber,
    required this.lane,
    this.shots = const [],
  });

  /// Checks if the frame is logically complete.
  /// Frames 1-9: Strike on shot 1, OR 2 shots taken
  /// Frame 10: Strike completes after 1 shot (enables frame 11), non-strike completes after 2 shots
  /// Frame 11: Strike on shot 1 enables frame 12, non-strike completes after 2 shots
  /// Frame 12: Always completes after 1 shot (only reached if strikes in both 10 and 11)
  bool get isComplete {
    if (shots.isEmpty) return false;
    
    // Frame 12: Only ever has 1 shot, so complete after that
    if (frameNumber == 12) return shots.length == 1;
    
    // Frame 11: Strike on shot 1 completes frame 11, non-strike needs 2 shots
    if (frameNumber == 11) {
      if (shots.isNotEmpty && shots.first.numOfPinsKnocked == 10) return true; // Strike
      return shots.length >= 2; // Non-strike needs 2 shots
    }
    
    // Frame 10: Strike completes after 1, non-strike after 2
    if (frameNumber == 10) {
      if (shots.first.numOfPinsKnocked == 10) return true; // Strike - complete after 1
      return shots.length >= 2; // Non-strike needs 2 shots
    }
    
    // Frames 1-9:
    if (shots.first.numOfPinsKnocked == 10) return true; // Strike
    if (shots.length >= 2) return true; // Two shots taken
    
    return false;
  }
  
  /// Helper to get the total number of pins down in this frame
  int get totalPinsDown => shots.fold(0, (sum, shot) => sum + shot.numOfPinsKnocked);
  
  /// Method to return a new Frame with an added shot (maintaining immutability principles)
  Frame copyWithShot(Shot newShot) {
    return Frame(
      frameNumber: frameNumber,
      lane: lane,
      shots: [...shots, newShot],
    );
  }

  Map<String, dynamic> toJson() => {
    'frameNumber': frameNumber,
    'lane': lane,
    'shots': shots.map((s) => s.toJson()).toList(),
  };

  static Frame fromJson(Map<String, dynamic> json) => Frame(
    frameNumber: json['frameNumber'] ?? 0,
    lane: json['lane'] ?? 1,
    shots: (json['shots'] as List<dynamic>?)
        ?.map((s) => Shot.fromJson(s as Map<String, dynamic>))
        .toList() ?? [],
  );
}