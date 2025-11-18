// controllers/session_controller.dart
import '../models/session.dart';
import '../models/shot.dart';
import 'local_cache.dart';
import 'ble_manager.dart';

class SessionController {
  final LocalCache cache;
  final BLEManager ble;

  // Use a singleton pattern or dependency injection (DI) in a real app
  static final SessionController _instance = SessionController._internal(LocalCache(), BLEManager());
  
  factory SessionController() => _instance;
  
  SessionController._internal(this.cache, this.ble) {
    // Attempt to load previous session on startup
    currentSession = cache.loadLastSession();
    _currentShotNumber = currentSession?.games
            .expand((game) => game.frames)
            .where((frame) => frame.shot != null)
            .length ??
        0;
  }

  GameSession? currentSession;

  int _currentShotNumber = 0; // Tracks the sequential shot number for the session

  void startNewSession(String sessionId) {
    currentSession = GameSession.newSession(sessionId);
    _currentShotNumber = 0; // Reset shot number
  }

  void endCurrentSession() {
    currentSession?.completeSession();
    persistAndSend();
  }

  /// Records a new shot and updates the current game state.
  void recordShot({
    required int lane,
    required List<bool> pinsStanding, // true = standing, false = down
    required int pinsDownCount, // # of pins knocked down
    required String position, // Outcome: "X", "/", "F", or the numeric count
    required double speed,
    required int hitBoard,
    
    // Optional/Default fields
    int ball = 1,
    bool isFoul = false,
  }) {
    if (currentSession == null) return;
    
    final activeGame = currentSession!.activeGame;
    if (activeGame == null) return;

    // Find the current active Frame (the first frame without a shot)
    final frameToUpdate = activeGame.currentFrame;
    if (frameToUpdate == null || frameToUpdate.shot != null) return; 

    // 1. Prepare data for Shot Model
    _currentShotNumber++;
    
    final leaveType = Shot.buildLeaveType(
      standingPins: pinsStanding,
      isFoul: isFoul,
    );

    final newShot = Shot(
      shotNumber: _currentShotNumber,
      ball: ball,
      count: pinsDownCount,
      leaveType: leaveType,
      timestamp: DateTime.now(),
      position: position,
      speed: speed,
      hitBoard: hitBoard,
    );

    // 2. Update Frame and Game
    frameToUpdate.shot = newShot;
    // This line is now valid because 'lane' in Frame is no longer final.
    if (frameToUpdate.lane != lane) {
        frameToUpdate.lane = lane;
        // Optionally update Game.lanes list here
    }

    // Note: Score calculation logic is omitted as it's complex. 
    // This is where you would call your scoring engine.
    // activeGame.score = calculateScore(activeGame);
    
    // 3. Persist and Send
    persistAndSend();
  }

  Future<void> persistAndSend() async {
    if (currentSession != null) {
      cache.saveSession(currentSession!);
      if (ble.isConnected) {
        await ble.sendSession(currentSession!);
      }
    }
  }
}