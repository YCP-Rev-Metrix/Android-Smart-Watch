class GameState {
  final int frameNumber;
  final int gameNumber;
  final int shotNumber;
  final int previousPins;

  GameState({
    required this.frameNumber,
    required this.gameNumber,
    required this.shotNumber,
    required this.previousPins,
  });
}

class AccountPacket {
  final int packetType; // 0x01
  final int version1;
  final int? version2;
  final int packetLength;

  // Session data
  final int sessionId;
  final String eventName;
  final int primaryHand; // 0=Left, 1=Right

  // Game data - now an array of per-game states
  final int gameCount;
  final List<GameState> gameStates; // Array of frame/shot for each game

  // Ball data
  final List<Ball> balls;

  // User data
  final String username;
  final int userId;
  final int lanes; // Number of lanes available

  AccountPacket({
    required this.packetType,
    required this.version1,
    this.version2,
    required this.packetLength,
    required this.sessionId,
    required this.eventName,
    required this.primaryHand,
    required this.gameCount,
    required this.gameStates,
    required this.balls,
    required this.username,
    required this.userId,
    this.lanes = 2,
  });

  // Convenience getters for single active game (backward compatibility)
  int? get frameNumber => gameStates.isNotEmpty ? gameStates.first.frameNumber : null;
  int? get gameNumber => gameStates.isNotEmpty ? gameStates.first.gameNumber : null;
  int? get shotNumber => gameStates.isNotEmpty ? gameStates.first.shotNumber : null;
  int? get previousPins => gameStates.isNotEmpty ? gameStates.first.previousPins : null;

  /// Parses a complete binary packet (all chunks reassembled)
  static AccountPacket fromBinary(List<int> data) {
    if (data.length < 3) {
      throw ArgumentError('Packet too short: ${data.length} bytes (minimum 3)');
    }

    int idx = 0;

    // Byte 0: Packet Type (must be 0x01)
    final packetType = data[idx++];
    if (packetType != 0x01) {
      throw ArgumentError('Invalid packet type: 0x${packetType.toRadixString(16)} (expected 0x01)');
    }

    // Byte 1: Version 1 (bit 7 indicates if V2 follows)
    final v1Byte = data[idx++];
    final version1 = v1Byte & 0x7F;
    final hasVersion2 = (v1Byte & 0x80) != 0;

    // Byte 2 (or 3 if V2): Packet Length
    int? version2;
    if (hasVersion2) {
      if (idx >= data.length) throw ArgumentError('Packet too short for version 2');
      version2 = data[idx++];
    }

    if (idx >= data.length) throw ArgumentError('Packet too short for packet length');
    final packetLength = data[idx++];

    // Validate packet length
    if (data.length < packetLength) {
      throw ArgumentError('Incomplete packet: ${data.length} bytes received, but header declares $packetLength bytes');
    }

    // Session ID: 4 bytes (uint32, little-endian)
    if (idx + 4 > data.length) throw ArgumentError('Packet too short for session ID');
    final sessionId = data[idx] | (data[idx + 1] << 8) | (data[idx + 2] << 16) | (data[idx + 3] << 24);
    idx += 4;

    // Event Name: null-terminated ASCII string
    final eventNameBytes = <int>[];
    while (idx < data.length && data[idx] != 0) {
      eventNameBytes.add(data[idx++]);
    }
    if (idx >= data.length) throw ArgumentError('Event name not null-terminated');
    idx++; // Skip null terminator
    final eventName = String.fromCharCodes(eventNameBytes);

    // Primary Hand: 1 byte (0=Left, 1=Right)
    if (idx >= data.length) throw ArgumentError('Packet too short for primary hand');
    final primaryHand = data[idx++];

    // Game Count: 2 bytes (uint16, little-endian)
    if (idx + 2 > data.length) throw ArgumentError('Packet too short for game count');
    final gameCount = data[idx] | (data[idx + 1] << 8);
    idx += 2;

    // Parse Game Data Array (for each game, 10 bytes: 4 frame + 2 game# + 2 shot# + 2 pins)
    final gameStates = <GameState>[];
    for (int i = 0; i < gameCount; i++) {
      // Frame Number: 4 bytes (uint32, little-endian)
      if (idx + 4 > data.length) throw ArgumentError('Packet too short for game $i frame number');
      final frameNumber = data[idx] | (data[idx + 1] << 8) | (data[idx + 2] << 16) | (data[idx + 3] << 24);
      idx += 4;

      // Game Number: 2 bytes (uint16, little-endian)
      if (idx + 2 > data.length) throw ArgumentError('Packet too short for game $i number');
      final gameNumber = data[idx] | (data[idx + 1] << 8);
      idx += 2;

      // Shot Number: 2 bytes (uint16, little-endian)
      if (idx + 2 > data.length) throw ArgumentError('Packet too short for game $i shot number');
      final shotNumber = data[idx] | (data[idx + 1] << 8);
      idx += 2;

      // Previous Pins: 2 bytes (uint16, little-endian)
      if (idx + 2 > data.length) throw ArgumentError('Packet too short for game $i previous pins');
      final previousPins = data[idx] | (data[idx + 1] << 8);
      idx += 2;

      gameStates.add(GameState(
        frameNumber: frameNumber,
        gameNumber: gameNumber,
        shotNumber: shotNumber,
        previousPins: previousPins,
      ));
    }

    // Ball Count: 1 byte
    if (idx >= data.length) throw ArgumentError('Packet too short for ball count');
    final ballCount = data[idx++];

    // Parse balls
    final balls = <Ball>[];
    for (int i = 0; i < ballCount; i++) {
      // Ball ID: 4 bytes (uint32, little-endian)
      if (idx + 4 > data.length) throw ArgumentError('Packet too short for ball $i ID');
      final ballId = data[idx] | (data[idx + 1] << 8) | (data[idx + 2] << 16) | (data[idx + 3] << 24);
      idx += 4;

      // Ball Name: null-terminated ASCII string
      final ballNameBytes = <int>[];
      while (idx < data.length && data[idx] != 0) {
        ballNameBytes.add(data[idx++]);
      }
      if (idx >= data.length) throw ArgumentError('Ball $i name not null-terminated');
      idx++; // Skip null terminator
      final ballName = String.fromCharCodes(ballNameBytes);

      balls.add(Ball(id: ballId, name: ballName));
    }

    // Username: null-terminated ASCII string
    if (idx >= data.length) throw ArgumentError('Packet too short for username');
    final usernameBytes = <int>[];
    while (idx < data.length && data[idx] != 0) {
      usernameBytes.add(data[idx++]);
    }
    if (idx >= data.length) throw ArgumentError('Username not null-terminated');
    idx++; // Skip null terminator
    final username = String.fromCharCodes(usernameBytes);

    // User ID: 4 bytes (uint32, little-endian)
    if (idx + 4 > data.length) throw ArgumentError('Packet too short for user ID');
    final userId = data[idx] | (data[idx + 1] << 8) | (data[idx + 2] << 16) | (data[idx + 3] << 24);
    idx += 4;

    // Lanes: 1 byte (number of lanes available)
    int lanes = 2; // Default to 2 if not present
    if (idx < data.length) {
      lanes = data[idx++];
      if (lanes == 0) lanes = 2; // Default to 2 if 0 is received
    }

    return AccountPacket(
      packetType: packetType,
      version1: version1,
      version2: version2,
      packetLength: packetLength,
      sessionId: sessionId,
      eventName: eventName,
      primaryHand: primaryHand,
      gameCount: gameCount,
      gameStates: gameStates,
      balls: balls,
      username: username,
      userId: userId,
      lanes: lanes,
    );
  }

  @override
  String toString() => '''AccountPacket(
    packetType: 0x${packetType.toRadixString(16)},
    version: $version1${version2 != null ? '.$version2' : ''},
    sessionId: $sessionId,
    eventName: $eventName,
    primaryHand: ${primaryHand == 0 ? 'Left' : 'Right'},
    gameCount: $gameCount,
    gameStates: [
      ${gameStates.map((gs) => 'Game ${gs.gameNumber}: frame=${gs.frameNumber}, shot=${gs.shotNumber}, previousPins=0x${gs.previousPins.toRadixString(16)}').join(',\n      ')}
    ],
    username: $username,
    userId: $userId,
    lanes: $lanes,
    balls: ${balls.map((b) => '${b.name}(id=${b.id})').join(', ')}
  )''';
}

class Ball {
  final int id;
  final String name;

  Ball({required this.id, required this.name});

  @override
  String toString() => '$name(id=$id)';
}
