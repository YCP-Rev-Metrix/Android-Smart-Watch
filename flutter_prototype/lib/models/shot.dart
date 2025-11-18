// models/shot.dart
class Shot {
  final int shotNumber; // (1 to N, overall shot of the session)
  final int ball; // ball ID #
  final int count; // # of pins knocked down (0-10)
  final int leaveType; // bitmask: first 10 bits = pins (1=up, 0=down), 11th bit = foul (1=foul)
  final String position; // where the ball hit the pocket (pocket quality)
  final DateTime timestamp;
  final double speed; // ball speed (mph)
  final int hitBoard; // where the ball hit

  static const int foulBit = 1 << 10; // 11th bit for foul

  Shot({
    required this.shotNumber,
    required this.ball,
    required this.count,
    required this.leaveType,
    required this.timestamp,
    required this.position,
    required this.speed,
    required this.hitBoard,
  });

  /// Calculates the number of pins standing (10 - count).
  int get pinsStanding => 10 - count;

  /// Returns true if a foul occurred (11th bit is set).
  bool get isFoul => (leaveType & foulBit) != 0;

  /// Returns a boolean list (true = standing, false = down) from the bitmask
  List<bool> get pinsState {
    final List<bool> pins = List.filled(10, false);
    for (int i = 0; i < 10; i++) {
      if ((leaveType & (1 << i)) != 0) {
        pins[i] = true; // Pin is standing
      }
    }
    return pins;
  }

  /// Helper to build the leaveType bitmask from a List<bool> (true=standing) and a foul status.
  static int buildLeaveType({required List<bool> standingPins, bool isFoul = false}) {
    int mask = 0;
    for (int i = 0; i < 10; i++) {
      if (standingPins[i]) {
        mask |= (1 << i);
      }
    }
    if (isFoul) {
      mask |= foulBit;
    }
    return mask;
  }

  Map<String, dynamic> toJson() => {
    'shotNumber': shotNumber,
    'ball': ball,
    'count': count,
    'leaveType': leaveType,
    'position': position,
    'timestamp': timestamp.toIso8601String(),
    'speed': speed,
    'hitBoard': hitBoard,
  };

  static Shot fromJson(Map<String, dynamic> json) => Shot(
    shotNumber: json['shotNumber'] ?? 0,
    ball: json['ball'] ?? 0,
    count: json['count'] ?? 0,
    leaveType: json['leaveType'] ?? 0,
    position: json['position'],
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    speed: (json['speed'] ?? 0.0).toDouble(),
    hitBoard: json['hitBoard'] ?? 18,
  );
}