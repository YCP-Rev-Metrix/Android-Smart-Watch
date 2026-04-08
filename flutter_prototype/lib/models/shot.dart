// models/shot.dart
class Shot {
  final int shotNumber;
  final int ball;
  final int numOfPinsKnocked;
  final int pins;
  final double impact;
  final double stance;
  final double target;
  final double breakPoint;
  final double speed;
  final int frameNum;
  final int lane;
  final bool isReadOnly; // True if this shot cannot be edited

  static const int foulBit = 1 << 10;
  static const Map<String, int> _impactBoardMap = {
    'gutter': 0,
    'right': 11,
    'light': 13,
    'light pocket': 16,
    'pocket': 17,
    'high pocket': 18,
    'high': 21,
    'nose': 20,
    'brooklyn': 23,
    'left': 27,
  };

  Shot({
    required this.shotNumber,
    required this.ball,
    required this.numOfPinsKnocked,
    required this.pins,
    num? impact,
    num? board,
    num? stance,
    num? target,
    num? breakPoint,
    required this.speed,
    required this.frameNum,
    required this.lane,
    this.isReadOnly = false,
  })  : impact = (impact ?? board ?? 17).toDouble(),
        stance = (stance ?? 20).toDouble(),
        target = (target ?? 20).toDouble(),
        breakPoint = (breakPoint ?? 20).toDouble();

  int get board => impact.round();

  /// Factory to create a read-only default shot with previous pins displayed
  factory Shot.readOnlyDefault({
    required int frameNum,
    required int lane,
    required List<bool> standingPins,
  }) {
    return Shot(
      shotNumber: 0,  // 0-based: first shot in frame
      ball: 3,
      numOfPinsKnocked: 10 - standingPins.fold(0, (sum, standing) => sum + (standing ? 1 : 0)),
      pins: buildPins(standingPins: standingPins, isFoul: false),
      board: 12,
      stance: 20,
      speed: 15.5,
      frameNum: frameNum,
      lane: lane,
      isReadOnly: true,
    );
  }

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

  static int impactToBoard(String impact) {
    if (impact.isEmpty) return 0;
    final key = impact.trim().toLowerCase();
    return _impactBoardMap[key] ?? 17;
  }

  static int secondShotImpactToBoard(String impact) {
    switch (impact.trim().toLowerCase()) {
      case 'right': return 1;
      case 'left': return 2;
      case 'chop': return 3;
      case 'tap': return 4;
      case 'gutter': return 5;
      case 'foul': return 6;
      default: return 0;
    }
  }

  Map<String, dynamic> toJson() => {
    'shotNumber': shotNumber,
    'ball': ball,
    'numOfPinsKnocked': numOfPinsKnocked,
    'pins': pins,
    'impact': impact,
    'board': impact,
    'stance': stance,
    'target': target,
    'breakPoint': breakPoint,
    'speed': speed,
    'frameNum': frameNum,
    'lane': lane,
    'isReadOnly': isReadOnly,
  };

  static Shot fromJson(Map<String, dynamic> json) => Shot(
    shotNumber: json['shotNumber'] ?? 0,
    ball: json['ball'] ?? 0,
    numOfPinsKnocked: json['numOfPinsKnocked'] ?? json['count'] ?? 0,
    pins: json['pins'] ?? json['leaveType'] ?? 0,
    impact: (json['impact'] ?? json['board'] ?? json['hitBoard'] ?? 18),
    stance: json['stance'] ?? 20,
    target: json['target'] ?? json['targetBoard'] ?? 20,
    breakPoint: json['breakPoint'] ?? json['breakpoint'] ?? 20,
    speed: (json['speed'] ?? 0.0).toDouble(),
    frameNum: json['frameNum'] ?? 0,
    lane: json['lane'] ?? 1,
    isReadOnly: json['isReadOnly'] ?? false,
  );

  /// Encodes shot into 23-byte binary packet for BLE transmission.
  /// Packet structure:
  ///   Byte 0:       Packet Type (e.g., 0x03 for shot)
  ///   Byte 1:       Version V1 (1-127, MSB=1 indicates V2 follows)
  ///   Byte 2:       Version V2 (optional, only if V1 MSB=1)
  ///   Byte 3:       Packet Length (size of packet)
  ///   Bytes 4-7:    Session ID (32-bit big-endian, max 4 billion)
  ///   Bytes 8-9:    Game(5) + Frame(4) + Shot#(1) + Ball ID(6) = 2 bytes
  ///   Bytes 10-11:  Pins(10) + Foul(1) + Unused(5) = 2 bytes
  ///   Byte 12:      Stance (0-100)
  ///   Byte 13:      Target (0-100)
  ///   Byte 14:      Break Point (0-100)
  ///   Byte 15:      Impact/Board (0-100, stored as x2 for 0.5 values)
  ///   Bytes 16-17:  Ball Speed (16-bit big-endian, stored as x10)
  ///   Byte 18:      Lane # (0-160)
  ///   Bytes 19-22:  Padding (4 bytes, zero-filled)
  List<int> encodeToBinary({
    required int sessionId,
    required int gameNumber,
    int packetType = 0x03,
    int version1 = 1,
    int? version2,
    int shotIndexInFrame = 1,
  }) {
    const int packetSize = 23; // 22 byte payload + 1 byte padding
    final buffer = List<int>.filled(packetSize, 0);

    int idx = 0;

    // Byte 0: Packet Type
    buffer[idx++] = packetType;

    // Byte 1: Version V1 (MSB indicates V2 presence)
    int v1 = version1 & 0x7F; // Keep lower 7 bits
    if (version2 != null) {
      v1 |= 0x80; // Set MSB to indicate V2 follows
    }
    buffer[idx++] = v1;

    // Byte 2: Version V2 (if present)
    if (version2 != null) {
      buffer[idx++] = version2 & 0xFF;
    } else {
      idx++; // Skip byte 2 if no V2
    }

    // Byte 3: Packet Length
    buffer[idx++] = packetSize;

    // Bytes 4-7: Session ID (32-bit big-endian)
    buffer[idx++] = (sessionId >> 24) & 0xFF;
    buffer[idx++] = (sessionId >> 16) & 0xFF;
    buffer[idx++] = (sessionId >> 8) & 0xFF;
    buffer[idx++] = sessionId & 0xFF;

    // Bytes 8-9: Game(5) + Frame(4) + Shot#(1) + Ball ID(6)
    // Shot# is 1-based index within frame: 1->0, 2->1, 3->1
    int shotNumberInPacket = (shotIndexInFrame > 1) ? 1 : 0;
    int gameFrameShotBall = 0;
    gameFrameShotBall |= (gameNumber & 0x1F) << 11; // Game: 5 bits
    gameFrameShotBall |= (frameNum & 0x0F) << 7;     // Frame: 4 bits
    gameFrameShotBall |= (shotNumberInPacket & 0x01) << 6;   // Shot#: 1 bit (0 or 1)
    gameFrameShotBall |= (ball & 0x3F);              // Ball ID: 6 bits
    buffer[idx++] = (gameFrameShotBall >> 8) & 0xFF;
    buffer[idx++] = gameFrameShotBall & 0xFF;

    // Bytes 10-11: Pins(10) + Foul(1) + Unused(5)
    // 'pins' already contains the 10-bit pin state and foul flag in bit 10
    buffer[idx++] = (pins >> 8) & 0xFF;
    buffer[idx++] = pins & 0xFF;

    // Byte 12: Stance (0-100, stored as x2 for 0.5 values)
    buffer[idx++] = ((stance * 2).toInt()) & 0xFF;

    // Byte 13: Target (0-100, stored as x2 for 0.5 values)
    buffer[idx++] = ((target * 2).toInt()) & 0xFF;

    // Byte 14: Break Point (0-100, stored as x2 for 0.5 values)
    buffer[idx++] = ((breakPoint * 2).toInt()) & 0xFF;

    // Byte 15: Impact/Board (0-100, stored as x2 for 0.5 values)
    // board is stored as x2 (e.g., 18.5 -> 37)
    buffer[idx++] = (board * 2) & 0xFF;

    // Bytes 16-17: Ball Speed (16-bit big-endian, stored as x10)
    final speedInt = (speed * 10).toInt();
    buffer[idx++] = (speedInt >> 8) & 0xFF;
    buffer[idx++] = speedInt & 0xFF;

    // Byte 18: Lane # (0-160)
    buffer[idx++] = lane & 0xFF;

    // Bytes 19-22: Padding (already filled with 0)

    return buffer;
  }

  /// Decodes a binary packet back to Shot object and session context.
  /// Returns a map with decoded shot and context data.
  static Map<String, dynamic> decodeFromBinary(List<int> data) {
    if (data.length < 23) {
      throw ArgumentError('Packet too small: ${data.length} bytes (expected 23)');
    }

    int idx = 0;

    // Byte 0: Packet Type
    final packetType = data[idx++];
    if (packetType != 0x03) {
      throw ArgumentError(
          'Invalid packet type: 0x${packetType.toRadixString(16)} (expected 0x03)');
    }

    // Byte 1: Version V1
    final v1Byte = data[idx++];
    final version1 = v1Byte & 0x7F;
    final hasVersion2 = (v1Byte & 0x80) != 0;

    // Byte 2: Version V2 (if present)
    final version2 = hasVersion2 ? data[idx++] : null;
    if (!hasVersion2) idx++; // Skip byte 2 if no V2

    // Byte 3: Packet Length
    final packetLength = data[idx++];
    if (packetLength != 23) {
      throw ArgumentError(
          'Unexpected packet length: $packetLength (expected 23)');
    }

    // Bytes 4-7: Session ID (32-bit big-endian)
    final sessionId = (data[idx] << 24) |
        (data[idx + 1] << 16) |
        (data[idx + 2] << 8) |
        data[idx + 3];
    idx += 4;

    // Bytes 8-9: Game(5) + Frame(4) + Shot#(1) + Ball ID(6)
    final gameFrameShotBall = (data[idx] << 8) | data[idx + 1];
    idx += 2;
    final gameNumber = (gameFrameShotBall >> 11) & 0x1F;
    final frameNumber = (gameFrameShotBall >> 7) & 0x0F;
    final shotNumber = (gameFrameShotBall >> 6) & 0x01;
    final ball = gameFrameShotBall & 0x3F;

    // Bytes 10-11: Pins(10) + Foul(1) + Unused(5)
    final pins = (data[idx] << 8) | data[idx + 1];
    idx += 2;


    // Byte 12: Stance (0-100, stored as x2 for 0.5 values)
    final stance = (data[idx++] / 2.0).round();

    // Byte 13: Target (0-100, stored as x2 for 0.5 values)
    final target = (data[idx++] / 2.0).round();

    // Byte 14: Break Point (0-100, stored as x2 for 0.5 values)
    final breakPoint = (data[idx++] / 2.0).round();

    // Byte 15: Impact/Board (0-100, stored as x2 for 0.5 values)
    final board = (data[idx++] / 2.0);

    // Bytes 16-17: Ball Speed (16-bit big-endian, stored as x10)
    final speedInt = (data[idx] << 8) | data[idx + 1];
    final speed = speedInt / 10.0;
    idx += 2;

    // Byte 18: Lane # (0-160)
    final lane = data[idx++];

    // Bytes 19-22: Padding (ignored)

    final shot = Shot(
      shotNumber: shotNumber,
      ball: ball,
      numOfPinsKnocked: 0, // Not encoded in new format
      pins: pins,
      board: board,
      stance: stance,
      speed: speed,
      frameNum: frameNumber,
      lane: lane,
    );

    return {
      'shot': shot,
      'sessionId': sessionId,
      'gameNumber': gameNumber,
      'frameNumber': frameNumber,
      'version1': version1,
      'version2': version2,
      'target': target,
      'breakPoint': breakPoint,
    };
  }
}