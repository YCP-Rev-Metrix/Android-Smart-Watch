// models/frame.dart

import 'shot.dart';

class Frame {
  final int frameNumber; // Frame # (1-10)
  int lane; // lane # for this frame/shot
  final List<Shot> shots; // List of shots for the frame

  Frame({
    required this.frameNumber,
    required this.lane,
    this.shots = const [], // Initialize as an empty list
  });

  /// Checks if the frame is logically complete (Strike, Spare, or two shots taken).
  bool get isComplete {
    if (shots.isEmpty) return false;
    
    // Check for a Strike (10 pins down on first shot)
    if (shots.first.count == 10) return true; 

    // Check for a Spare or Open Frame (two shots taken)
    if (shots.length >= 2) return true;

    // Additional logic for 10th frame bonuses would go here, but this covers 1-9.
    return false;
  }
  
  /// Helper to get the total number of pins down in this frame
  int get totalPinsDown => shots.fold(0, (sum, shot) => sum + shot.count);
  
  /// Method to return a new Frame with an added shot (maintaining immutability principles)
  Frame copyWithShot(Shot newShot) {
    return Frame(
      frameNumber: frameNumber,
      lane: lane,
      shots: [...shots, newShot], // Add the new shot to the list
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