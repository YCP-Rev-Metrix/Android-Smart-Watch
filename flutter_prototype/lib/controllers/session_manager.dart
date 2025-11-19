// session_manager.dart is independent of UI pages; removed unused imports

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  // Store frames (10 frames with 2 shots each)
  final List<Map<String, dynamic>> _frames = List.generate(10, (_) => {
        'shots': [
          {'pins': List.filled(10, false), 'lane': 1, 'board': 18, 'speed': 15.0},
          {'pins': List.filled(10, false), 'lane': 1, 'board': 18, 'speed': 15.0}
        ],
        'score': 0,
      });

  Map<String, dynamic> getShot(int frame, int shot) =>
      _frames[frame]['shots'][shot - 1];

  void updateShot(int frame, int shot, Map<String, dynamic> newData) {
  _frames[frame]['shots'][shot - 1] = newData;
  if (shot == 1) {
    // copy shot 1 pins into shot 2 when first completed
    final shot2 = _frames[frame]['shots'][1];
    shot2['pins'] = List<bool>.from(newData['pins']);
  }
  _updateFrameScore(frame);
}

  void _updateFrameScore(int frameIndex) {
    final frame = _frames[frameIndex];
    final pins = frame['shots']
        .expand((s) => s['pins'] as List<bool>)
        .where((p) => p)
        .length;
    frame['score'] = pins;
  }

  int getFrameScore(int frame) => _frames[frame]['score'];

  void resetFrame(int frame) {
    _frames[frame] = {
      'shots': [
        {'pins': List.filled(10, false), 'lane': 1, 'board': 18, 'speed': 15.0},
        {'pins': List.filled(10, false), 'lane': 1, 'board': 18, 'speed': 15.0}
      ],
      'score': 0,
    };
  }
}
