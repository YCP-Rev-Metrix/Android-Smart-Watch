class AccountPacket {
  final int packetType; // 0x01
  final int version1;
  final int? version2;
  final int packetLength;

  // Session data
  final int sessionId;
  final String eventName;
  final int? frameNumber;
  final int? gameNumber;
  final int? shotNumber;
  final int primaryHand; // 0=Left, 1=Right

  // Ball data
  final List<Ball> balls;

  // User data
  final String username;
  final int userId;

  AccountPacket({
    required this.packetType,
    required this.version1,
    this.version2,
    required this.packetLength,
    required this.sessionId,
    required this.eventName,
    this.frameNumber,
    this.gameNumber,
    this.shotNumber,
    required this.primaryHand,
    required this.balls,
    required this.username,
    required this.userId,
  });

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

    // Session ID: 4 bytes (uint32, big-endian)
    if (idx + 4 > data.length) throw ArgumentError('Packet too short for session ID');
    final sessionId = (data[idx] << 24) | (data[idx + 1] << 16) | (data[idx + 2] << 8) | data[idx + 3];
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

    // Frame Number: 4 bytes (uint32, big-endian) - 0 if no active games
    if (idx + 4 > data.length) throw ArgumentError('Packet too short for frame number');
    final frameNumber = (data[idx] << 24) | (data[idx + 1] << 16) | (data[idx + 2] << 8) | data[idx + 3];
    idx += 4;

    // Game Number: 2 bytes (uint16, big-endian) - 0 if no active games
    if (idx + 2 > data.length) throw ArgumentError('Packet too short for game number');
    final gameNumber = (data[idx] << 8) | data[idx + 1];
    idx += 2;

    // Shot Number: 2 bytes (uint16, big-endian) - 0 if no active games
    if (idx + 2 > data.length) throw ArgumentError('Packet too short for shot number');
    final shotNumber = (data[idx] << 8) | data[idx + 1];
    idx += 2;

    // Ball Count: 1 byte
    if (idx >= data.length) throw ArgumentError('Packet too short for ball count');
    final ballCount = data[idx++];

    // Parse balls
    final balls = <Ball>[];
    for (int i = 0; i < ballCount; i++) {
      // Ball ID: 4 bytes (uint32, big-endian)
      if (idx + 4 > data.length) throw ArgumentError('Packet too short for ball $i ID');
      final ballId = (data[idx] << 24) | (data[idx + 1] << 16) | (data[idx + 2] << 8) | data[idx + 3];
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

    // User ID: 4 bytes (uint32, big-endian)
    if (idx + 4 > data.length) throw ArgumentError('Packet too short for user ID');
    final userId = (data[idx] << 24) | (data[idx + 1] << 16) | (data[idx + 2] << 8) | data[idx + 3];

    return AccountPacket(
      packetType: packetType,
      version1: version1,
      version2: version2,
      packetLength: packetLength,
      sessionId: sessionId,
      eventName: eventName,
      frameNumber: frameNumber,
      gameNumber: gameNumber,
      shotNumber: shotNumber,
      primaryHand: primaryHand,
      balls: balls,
      username: username,
      userId: userId,
    );
  }

  @override
  String toString() => '''AccountPacket(
    packetType: 0x${packetType.toRadixString(16)},
    version: $version1${version2 != null ? '.$version2' : ''},
    sessionId: $sessionId,
    eventName: $eventName,
    frameNumber: $frameNumber,
    gameNumber: $gameNumber,
    shotNumber: $shotNumber,
    primaryHand: ${primaryHand == 0 ? 'Left' : 'Right'},
    username: $username,
    userId: $userId,
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
