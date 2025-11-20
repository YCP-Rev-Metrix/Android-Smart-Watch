// lib/controllers/session_controller.dart

import 'package:flutter/foundation.dart';
import '../models/frame.dart'; 
import '../models/shot.dart'; 

// ----------------------------------------------------------------------
// 1. Core Model Structure 
// ----------------------------------------------------------------------

class Game {
  final int gameNumber;
  final List<Frame> frames;
  final int totalScore; 

  Game({required this.gameNumber, required this.frames, required this.totalScore});

  static Game createEmpty(int gameNumber, int totalScore) {
    return Game(
      gameNumber: gameNumber,
      frames: List.generate(10, (i) => Frame(frameNumber: i + 1, lane: 1)),
      totalScore: totalScore,
    );
  }
  
  Game copyWithFrame({required int index, required Frame newFrame}) {
    final updatedFrames = List<Frame>.from(frames);
    if (index >= 0 && index < updatedFrames.length) {
      updatedFrames[index] = newFrame;
    }
    return Game(
      gameNumber: gameNumber,
      frames: updatedFrames,
      totalScore: totalScore, 
    );
  }
}

class SessionModel {
  final String sessionId;
  final List<String> balls;
  final List<Game> games; 
  int get numOfGames => games.length;
  
  SessionModel({
    required this.games,
  }) : sessionId = 'SESSION_${DateTime.now().millisecondsSinceEpoch}',
    balls = const ['Ball A', 'Ball B', 'Ball C'];
}


// #############################################################
//                         2. SESSION CONTROLLER 
// #############################################################

class SessionController extends ChangeNotifier { 
  
  // --- Singleton Pattern ---
  static final SessionController _instance = SessionController._internal();
  
  factory SessionController() {
    if (_instance.currentSession == null) {
      _instance._initializeHardcodedSession();
    }
    return _instance;
  }
  SessionController._internal();

  SessionModel? currentSession; 
  
  // --- Initialization & Setup ---
  
  Shot _createTestShot({
    required int shotNumber, 
    required int count, 
    required List<bool> standingPins, 
    bool isFoul = false,
    String position = 'Pocket',
  }) {
    // Correct parameter name: standingPins
    final leaveType = Shot.buildLeaveType(standingPins: standingPins, isFoul: isFoul);
    return Shot(
      shotNumber: shotNumber,
      ball: 1, // Default to Ball 1
      count: count,
      leaveType: leaveType,
      timestamp: DateTime.now().add(Duration(seconds: shotNumber)),
      position: position,
      speed: 15.5 + (shotNumber % 3) * 0.1,
      hitBoard: 12 + (shotNumber % 5),
    );
  }

  void _initializeTestData() {
    int globalShotCount = 1;
    final List<Frame> detailedFrames = [];

    // --- Frame 1 (Index 0): Strike (X) - Cumulative Score: 30 ---
    final shot1 = _createTestShot(
      shotNumber: globalShotCount++,
      count: 10,
      standingPins: List.filled(10, false),
      position: 'Strike',
    );
    detailedFrames.add(Frame(
      frameNumber: 1, 
      lane: 1, 
      shots: [shot1]
    ));

    // --- Frame 2 (Index 1): 7 Spare (7 /) - Cumulative Score: 50 ---
    final shot2 = _createTestShot(
      shotNumber: globalShotCount++,
      count: 7,
      standingPins: [false, false, false, false, false, false, false, true, true, true],
      position: '7 Pin',
    );
    final shot3 = _createTestShot(
      shotNumber: globalShotCount++,
      count: 3, 
      standingPins: List.filled(10, false),
      position: 'Spare',
    );
    detailedFrames.add(Frame(
      frameNumber: 2, 
      lane: 1, 
      shots: [shot2, shot3]
    ));

    // --- Frame 3 (Index 2): Open Frame (8, 1) - Cumulative Score: 59 ---
    final shot4 = _createTestShot(
      shotNumber: globalShotCount++,
      count: 8,
      standingPins: [false, true, false, false, false, false, false, false, false, false],
      position: 'Pocket',
    );
    final shot5 = _createTestShot(
      shotNumber: globalShotCount++,
      count: 1, 
      standingPins: [false, true, false, false, false, false, false, false, false, false],
      position: 'Tap',
    );
    detailedFrames.add(Frame(
      frameNumber: 3, 
      lane: 1, 
      shots: [shot4, shot5]
    ));

    // --- Frame 4 (Index 3): Active Frame (Empty, waiting for input) ---
    detailedFrames.add(Frame(
      frameNumber: 4, 
      lane: 1, 
      shots: const [] 
    ));


    // 3. Pad the rest of the game with empty frames up to 10
    int currentFrameCount = detailedFrames.length;
    final emptyFrames = List.generate(10 - currentFrameCount, (index) => Frame(
      frameNumber: index + currentFrameCount + 1,
      lane: 1, 
      shots: const [],
    ));

    // 4. Create the Game object
    final testGame = Game(
      gameNumber: 1,
      frames: [...detailedFrames, ...emptyFrames],
      totalScore: 59, 
    );
    
    // 5. Create the full test session
    final simpleGames = _createSimpleTestGames(6); 
    currentSession = SessionModel(
      games: [testGame, ...simpleGames], 
    );
  }
  
  List<Game> _createSimpleTestGames(int count) {
    return List.generate(count, (gameIndex) {
      final int testScore = switch (gameIndex) {
        0 => 120, 
        1 => 80, 
        2 => 55, 
        3 => 90, 
        4 => 85, 
        _ => 0,
      };
      
      return Game.createEmpty(gameIndex + 2, testScore);
    });
  }

  void _initializeHardcodedSession() {
    _initializeTestData(); 
  }
  
  // --- Controller Methods ---

  /// Finds the index of the first frame in the active game that is NOT complete.
  int get activeFrameIndex {
    final activeGame = currentSession?.games.first;
    if (activeGame == null) return 0;
    
    final index = activeGame.frames.indexWhere((f) => !f.isComplete);
    
    // If all frames are complete, return the last frame index (9, for the 10th frame)
    return index == -1 ? activeGame.frames.length - 1 : index;
  }
  
  void createNewSessionFromPacket(List<Game> parsedGames) {
    currentSession = SessionModel(games: parsedGames);
    notifyListeners(); 
  }

  void createNewSession({int numOfGames = 3}) {
    final newGames = _createSimpleTestGames(numOfGames);
    createNewSessionFromPacket(newGames);
  }

  void recordShot({
    required int lane,
    required double speed,
    required int hitBoard,
    required int ball,
    // Corrected parameter name
    required List<bool> standingPins, 
    required int pinsDownCount,
    required String position,
    required bool isFoul,
  }) {
    // 1. Find the active Game and Frame
    final activeGame = currentSession?.games.first; 
    final activeFrameIndex = activeGame?.frames.indexWhere((f) => !f.isComplete) ?? -1;

    if (activeGame != null && activeFrameIndex != -1) {
      final oldFrame = activeGame.frames[activeFrameIndex];
      
      final globalShotNumber = activeGame.frames.fold<int>(0, (sum, f) => sum + f.shots.length) + 1;

      // 2. Create the new Shot object
      final newShot = Shot(
        shotNumber: globalShotNumber,
        ball: ball, 
        count: pinsDownCount,
        // Corrected parameter name
        leaveType: Shot.buildLeaveType(standingPins: standingPins, isFoul: isFoul), 
        timestamp: DateTime.now(),
        position: position,
        speed: speed,
        hitBoard: hitBoard,
      );

      // 3. Create the new Frame (immutable update)
      final newFrame = oldFrame.copyWithShot(newShot);
      
      // 4. Create the new Game (immutable update)
      final newGame = activeGame.copyWithFrame(index: activeFrameIndex, newFrame: newFrame);
      
      // 5. Update the session
      currentSession = SessionModel(
        games: [newGame, ...currentSession!.games.skip(1)],
      );
    }
    
    notifyListeners();
  }
  
  /// Edits an existing shot in a frame by replacing the Shot object at a specific index.
  void editShot({
    required int frameIndex,
    required int shotIndexInFrame, // 0-based index of the shot within the frame
    required int lane,
    required double speed,
    required int hitBoard,
    required int ball,
    // Corrected parameter name
    required List<bool> standingPins,
    required int pinsDownCount,
    required String position,
    required bool isFoul,
  }) {
    final activeGame = currentSession?.games.first;

    if (activeGame != null && frameIndex >= 0 && frameIndex < activeGame.frames.length) {
      final oldFrame = activeGame.frames[frameIndex];
      final oldShots = oldFrame.shots;

      if (shotIndexInFrame >= 0 && shotIndexInFrame < oldShots.length) {
        final oldShot = oldShots[shotIndexInFrame];
        
        // 1. Create the new Shot object, maintaining the original shotNumber and timestamp
        final updatedShot = Shot(
          shotNumber: oldShot.shotNumber,
          ball: ball, 
          count: pinsDownCount,
          // Corrected parameter name
          leaveType: Shot.buildLeaveType(standingPins: standingPins, isFoul: isFoul), 
          timestamp: oldShot.timestamp, // Keep the original timestamp
          position: position,
          speed: speed,
          hitBoard: hitBoard,
        );

        // 2. Create the new list of shots with the updated shot
        final newShots = List<Shot>.from(oldShots);
        newShots[shotIndexInFrame] = updatedShot;

        // 3. Create the new Frame (immutable update)
        final newFrame = Frame(
            frameNumber: oldFrame.frameNumber, 
            lane: lane, 
            shots: newShots
        );
        
        // 4. Create the new Game (immutable update)
        final newGame = activeGame.copyWithFrame(index: frameIndex, newFrame: newFrame);
        
        // 5. Update the session
        currentSession = SessionModel(
          games: [newGame, ...currentSession!.games.skip(1)],
        );
        
        // NOTE: In a complete application, you must call a recalculateScores() method here.
      }
    }
    
    notifyListeners();
  }
  
  int get numOfGames {
    return currentSession?.games.length ?? 1;
  }

  void setActiveGame(int gameIndex) {
    notifyListeners(); 
  }
}