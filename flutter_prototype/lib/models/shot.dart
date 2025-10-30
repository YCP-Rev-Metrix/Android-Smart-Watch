class Shot {
  final int shotNumber;
  final int ball;
  final int board;
  final int lane;
  final double ballSpeed;
  final List<bool> pins;
  final String? outcome;
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

  int get pinCount => 0;
  Map<String, dynamic> toJson() => {};
  static Shot fromJson(Map<String, dynamic> json) => Shot(
        shotNumber: 0,
        ball: 0,
        board: 0,
        lane: 0,
        ballSpeed: 0,
        pins: const [],
        timestamp: DateTime.now(),
      );
}
