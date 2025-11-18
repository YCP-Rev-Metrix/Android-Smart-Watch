// lib/controllers/session_controller.dart

import 'package:flutter/foundation.dart';

// ----------------------------------------------------------------------
// 1. Core Model Structure (Reflecting required schema and list-driven logic)
// ----------------------------------------------------------------------
class SessionModel {
  final String sessionId;
  final int numOfGames; // Derived from the games list length
  final List<String> balls; // Array of ball names/ids
  final List<Game> games; // The definitive source of truth
  
  // The constructor accepts the final list of games, which is the source of truth.
  SessionModel({
    required this.games,
  })  : sessionId = 'SESSION_${DateTime.now().millisecondsSinceEpoch}',
        balls = const ['Ball A', 'Ball B', 'Ball C'], // Hardcoded test balls
        // CRITICAL: numOfGames is calculated from the list length to guarantee sync.
        numOfGames = games.length; 
}

class Game {
  final int numOfFrames;
  final List<Frame> frames;
  final int totalScore; 
  
  Game({required this.numOfFrames, required this.totalScore})
      : frames = List.generate(numOfFrames, (frameIndex) => Frame(score: 10));
}

class Frame {
  dynamic shot;
  final int score; 
  
  Frame({required this.score});
}
// ----------------------------------------------------------------------


class SessionController extends ChangeNotifier { 
  
  // --- Singleton Pattern ---
  static final SessionController _instance = SessionController._internal();
  
  // Initialize with hardcoded test data (5 games) when the controller is first accessed.
  factory SessionController() {
      if (_instance.currentSession == null) {
          _instance._initializeHardcodedSession();
      }
      return _instance;
  }
  SessionController._internal();

  SessionModel? currentSession; 
  
  // --- Initialization & Setup ---

  // Utility to create the test array of games (simulates parsing a packet)
  List<Game> _createTestGames(int count) {
    return List.generate(count, (gameIndex) {
      // Hardcoded test scores for UI verification
      final int testScore = switch (gameIndex) {
        0 => 120, // Game 1
        1 => 80,  // Game 2
        2 => 55,  // Game 3
        3 => 90,  // Game 4
        4 => 85,  // Game 5
        _ => 0,
      };
      return Game(numOfFrames: 10, totalScore: testScore);
    });
  }

  void _initializeHardcodedSession() {
      // Create and pass the list of 5 games
      final testGames = _createTestGames(7);
      currentSession = SessionModel(games: testGames); 
  }
  
  // --- Controller Methods ---

  // Method simulating reception and parsing of a Bluetooth packet
  void createNewSessionFromPacket(List<Game> parsedGames) {
      // The SessionModel constructor handles deriving numOfGames from parsedGames.length
      currentSession = SessionModel(games: parsedGames);
      notifyListeners(); 
  }

  // Legacy method signature maintained for existing calls
  void createNewSession({int numOfGames = 3}) {
      final newGames = _createTestGames(numOfGames);
      createNewSessionFromPacket(newGames);
  }

  void recordShot({
    required int lane,
    required double speed,
    required int hitBoard,
    required int ball,
    required List<bool> pinsStanding,
    required int pinsDownCount,
    required String position,
    required bool isFoul,
  }) {
    // Logic to update state
    notifyListeners();
  }
  
  // CRITICAL: The UI/GameShell reads the array length directly for dynamic updates.
  int get numOfGames {
    return currentSession?.games.length ?? 1;
  }

  void setActiveGame(int gameIndex) {
      // Logic to track the currently active game
      notifyListeners(); 
  }
}