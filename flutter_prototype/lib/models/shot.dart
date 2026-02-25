// models/shot.dart
class Shot {
  final int shotNumber;
  final int ball;
  final int numOfPinsKnocked;
  final int pins;
  final int board;
  final int stance;
  final double speed;
  final int frameNum;
  final int lane;

  static const int foulBit = 1 << 10;

  Shot({
    required this.shotNumber,
    required this.ball,
    required this.numOfPinsKnocked,
    required this.pins,
    required this.board,
    required this.stance,
    required this.speed,
    required this.frameNum,
    required this.lane,
  });

  /// Calculates the number of pins standing (10 - numOfPinsKnocked).
  int get pinsStanding => 10 - numOfPinsKnocked;

  /// Returns true if a foul occurred (11th bit is set).
  bool get isFoul => (pins & foulBit) != 0;

  /// Returns a boolean list (true = standing, false = down) from the bitmask.
  List<bool> get pinsState {
    final List<bool> state = List.filled(10, false);
    for (int i = 0; i < 10; i++) {
      if ((pins & (1 << i)) != 0) {
        state[i] = true; // Pin is standing
      }
    }
    return state;
  }

  /// Helper to build the pins bitmask from a List<bool> (true=standing) and a foul status.
  static int buildPins({required List<bool> standingPins, bool isFoul = false}) {
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

  /// Alias kept for compatibility while callers are updated.
  static int buildLeaveType({required List<bool> standingPins, bool isFoul = false}) =>
      buildPins(standingPins: standingPins, isFoul: isFoul);

  Map<String, dynamic> toJson() => {
    'shotNumber': shotNumber,
    'ball': ball,
    'numOfPinsKnocked': numOfPinsKnocked,
    'pins': pins,
    'board': board,
    'stance': stance,
    'speed': speed,
    'frameNum': frameNum,
    'lane': lane,
  };

  static Shot fromJson(Map<String, dynamic> json) => Shot(
    shotNumber: json['shotNumber'] ?? 0,
    ball: json['ball'] ?? 0,
    numOfPinsKnocked: json['numOfPinsKnocked'] ?? json['count'] ?? 0,
    pins: json['pins'] ?? json['leaveType'] ?? 0,
    board: json['board'] ?? json['hitBoard'] ?? 18,
    stance: json['stance'] ?? 20,
    speed: (json['speed'] ?? 0.0).toDouble(),
    frameNum: json['frameNum'] ?? 0,
    lane: json['lane'] ?? 1,
  );
}