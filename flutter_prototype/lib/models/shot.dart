class Shot {
  final int shotNumber;
  final int ball;           // ball ID
  final int board;          // board hit
  final int lane;           // lane number
  final double ballSpeed;   // mph
  final List<bool> pins;    // true = standing, false = down
  final String? outcome;    // strike, spare, split, etc.
  final DateTime timestamp;

  Shot({
    required this.shotNumber,
    required this.ball,
    required this.board,
    required this.lane,
    required this.ballSpeed,
    required this.pins,
    required this.timestamp,
    this.outcome,
  });

  int get pinCount => pins.where((p) => !p).length;

  Map<String, dynamic> toJson() => {
        'shotNumber': shotNumber,
        'ball': ball,
        'board': board,
        'lane': lane,
        'ballSpeed': ballSpeed,
        'pins': pins,
        'outcome': outcome,
        'timestamp': timestamp.toIso8601String(),
      };

  static Shot fromJson(Map<String, dynamic> json) => Shot(
        shotNumber: json['shotNumber'] ?? 0,
        ball: json['ball'] ?? 0,
        board: json['board'] ?? 0,
        lane: json['lane'] ?? 0,
        ballSpeed: (json['ballSpeed'] ?? 0).toDouble(),
        pins: List<bool>.from(json['pins'] ?? []),
        outcome: json['outcome'],
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );
}
