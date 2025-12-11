// lib/controllers/session_controller.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  // Singleton pattern
  static final SessionController _instance = SessionController._internal();
  
  factory SessionController() {
    if (_instance.currentSession == null) {
      _instance._initializeHardcodedSession();
    }
    return _instance;
  }
  SessionController._internal();

  SessionModel? currentSession; 
  
  // _activeFrameIndex: 0-9 for the 10 main frames. Set to 10 for game over.
  int _activeFrameIndex = 0; 
  // _activeShotIndex: 1, 2, or 3 (for the 10th frame)
  int _activeShotIndex = 1; 

  int get activeFrameIndex => _activeFrameIndex; 
  int get activeShotIndex => _activeShotIndex; 

  // Default selections for new shots
  int defaultLane = 1;
  int defaultBoard = 18;
  int defaultBall = 1;
  double defaultSpeed = 15.0;

  // Initialize test data with a detailed first game
  Shot _createTestShot({
    required int shotNumber, 
    required int count, 
    required List<bool> standingPins, 
    bool isFoul = false,
    String position = 'Pocket',
  }) {
    final leaveType = Shot.buildLeaveType(standingPins: standingPins, isFoul: isFoul);
    return Shot(
      shotNumber: shotNumber,
      ball: 1,
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


    // Pad the rest of the game with empty frames up to 10
    int currentFrameCount = detailedFrames.length;
    final emptyFrames = List.generate(10 - currentFrameCount, (index) => Frame(
      frameNumber: index + currentFrameCount + 1,
      lane: 1, 
      shots: const [],
    ));

    //Create the Game object
    final testGame = Game(
      gameNumber: 1,
      frames: [...detailedFrames, ...emptyFrames],
      totalScore: 59, 
    );
    
    // Create the full test session
    final simpleGames = _createSimpleTestGames(6); 
    currentSession = SessionModel(
      games: [testGame, ...simpleGames], 
    );
    
    // Set active input position after initializing test data (Frame 4, Shot 1)
    _activeFrameIndex = 3; 
    _activeShotIndex = 1;
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

  void createNewSessionFromPacket(List<Game> parsedGames) {
    currentSession = SessionModel(games: parsedGames);
    _activeFrameIndex = 0;
    _activeShotIndex = 1;
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
    required List<bool> standingPins, 
    required int pinsDownCount,
    required String position,
    required bool isFoul,
  }) {
    // 1. Find the active Game and Frame
    final activeGame = currentSession?.games.first; 
    // Use the stored active index
    final activeFrameIndexForUpdate = _activeFrameIndex;

    // Check for game over state
    if (activeGame == null || activeFrameIndexForUpdate >= 10) return;

    final oldFrame = activeGame.frames[activeFrameIndexForUpdate];
    
    // Logger: print current active indices and shot counts before recording
    try {
      debugPrint('Recording shot - activeFrameIndex=$_activeFrameIndex, activeShotIndex=$_activeShotIndex');
      for (var i = 0; i < activeGame.frames.length; i++) {
        debugPrint('Game ${activeGame.gameNumber} Frame ${i + 1} shots=${activeGame.frames[i].shots.length}');
      }
    } catch (e) {
      debugPrint('Diagnostic print failed: $e');
    }

    final globalShotNumber = activeGame.frames.fold<int>(0, (sum, f) => sum + f.shots.length) + 1;

    // 2. Create the new Shot object
    final newShot = Shot(
      shotNumber: globalShotNumber,
      ball: ball, 
      count: pinsDownCount,
      leaveType: Shot.buildLeaveType(standingPins: standingPins, isFoul: isFoul), 
      timestamp: DateTime.now(),
      position: position,
      speed: speed,
      hitBoard: hitBoard,
    );

    // 3. Create the new Frame (immutable update)
    final newFrame = Frame(
        frameNumber: oldFrame.frameNumber,
        lane: lane, 
        shots: [...oldFrame.shots, newShot],
    );
    
    // 4. Create the new Game (immutable update)
    final newGame = activeGame.copyWithFrame(index: activeFrameIndexForUpdate, newFrame: newFrame);
    
    // 5. Update the session
    currentSession = SessionModel(
      games: [newGame, ...currentSession!.games.skip(1)],
    );

    _advanceFrameAndShot(newFrame);

    // Persist the user's last selections as global defaults for subsequent shots
    defaultLane = lane;
    defaultSpeed = speed;
    defaultBoard = hitBoard;
    defaultBall = ball;

    // Logger: print shot info and frame shot counts after constructing newFrame/newGame but before assigning
    try {
      debugPrint('New shot created: shotNumber=$globalShotNumber, count=$pinsDownCount, position=$position, isFoul=$isFoul');
      debugPrint('NewFrame shots count (will be): ${newFrame.shots.length} for frame ${newFrame.frameNumber}');
    } catch (_) {}

    // Build a nested JSON representation of the in-memory session (Session -> Games -> Frames -> Shots)
    try {
      final sessionMap = {
        'sessionId': currentSession?.sessionId ?? '',
        'games': currentSession!.games.map((g) => {
              'gameNumber': g.gameNumber,
              'totalScore': g.totalScore,
              'frames': g.frames.map((f) => f.toJson()).toList(),
            }).toList(),
      };

      // Logger: print the session JSON structure.
      final pretty = const JsonEncoder.withIndent('  ').convert(sessionMap);
      for (final line in pretty.split('\n')) {
        debugPrint(line);
      }
      _saveSessionJsonToDocuments(pretty, filename: 'RevMetrix.json');
      // Print per-game/frame shot counts to make it easy to see progress
      for (var gi = 0; gi < currentSession!.games.length; gi++) {
        final g = currentSession!.games[gi];
        final frameShotCounts = g.frames.map((f) => f.shots.length).toList();
        debugPrint('Game ${g.gameNumber} frame shot counts: $frameShotCounts');
      }
    } catch (e, st) {
      debugPrint('Failed to build session JSON: $e\n$st');
    }

    notifyListeners();
  }

  // Logic to determine the next input location (Frame/Shot)
  void _advanceFrameAndShot(Frame newFrame) {
    final frameNumber = newFrame.frameNumber;
    final shotCount = newFrame.shots.length;
    
    // Logic for Frames 1 through 9 (index 0-8)
    if (frameNumber < 10) {
      if (newFrame.isComplete) {
        // Frame is complete (Strike on shot 1, or two shots taken)
        _activeFrameIndex++;
        _activeShotIndex = 1;
      } else {
        // Not a strike on shot 1, move to shot 2 of the current frame
        _activeShotIndex = 2; 
      }
    } 
    // Logic for Frame 10 (index 9)
    else if (frameNumber == 10) {
      if (shotCount == 1) {
        // First shot taken. Needs at least a second shot.
        _activeShotIndex = 2;
      } else if (shotCount == 2) {
        // Check if a bonus shot is earned (Strike or Spare)
        final totalPins = newFrame.totalPinsDown;
        if (totalPins >= 10) {
          // Strike or Spare, needs shot 3
          _activeShotIndex = 3;
        } else {
          // Open frame (less than 10 pins in 2 shots), game is over
          _activeFrameIndex = 10;
          _activeShotIndex = 1;
        }
      } else if (shotCount == 3) {
        // Third shot complete, game is over
        _activeFrameIndex = 10; 
        _activeShotIndex = 1;
      }
    }
  }
  
  /// Edits an existing shot in a frame by replacing the Shot object at a specific index.
  void editShot({
    required int frameIndex,
    required int shotIndexInFrame,
    required int lane,
    required double speed,
    required int hitBoard,
    required int ball,
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
          leaveType: Shot.buildLeaveType(standingPins: standingPins, isFoul: isFoul), 
          timestamp: oldShot.timestamp,
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
        
        try {
          final sessionMap = {
            'sessionId': currentSession?.sessionId ?? '',
            'games': currentSession!.games.map((g) => {
                  'gameNumber': g.gameNumber,
                  'totalScore': g.totalScore,
                  'frames': g.frames.map((f) => f.toJson()).toList(),
                }).toList(),
          };
          final prettyEdit = const JsonEncoder.withIndent('  ').convert(sessionMap);
          for (final line in prettyEdit.split('\n')) debugPrint(line);
          _saveSessionJsonToDocuments(prettyEdit, filename: 'RevMetrix.json');
        } catch (e, st) {
          debugPrint('Failed to build session JSON after edit: $e\n$st');
        }
      }
    }
    
    notifyListeners();
  }

  Future<void> _saveSessionJsonToDocuments(String pretty, {required String filename}) async {
    // Try direct write to the shared Documents folder first (/storage/emulated/0/Documents)
    try {
      final directPath = '/storage/emulated/0/Documents';
      final dir = Directory(directPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('$directPath/$filename');
      await file.writeAsString(pretty, flush: true);
      debugPrint('Session JSON saved to shared Documents: ${file.path}');
      return;
    } catch (e) {
      debugPrint('Failed to write to shared Documents (/storage/emulated/0/Documents): $e');
    }

    // Try: app-specific external Documents (may still be visible under Android/data/.../files/Documents)
    try {
      final extDirs = await getExternalStorageDirectories(type: StorageDirectory.documents);
      if (extDirs != null && extDirs.isNotEmpty) {
        final externalDir = extDirs.first;
        final file = File('${externalDir.path}/$filename');
        await file.create(recursive: true);
        await file.writeAsString(pretty, flush: true);
        debugPrint('Session JSON saved to external Documents: ${file.path}');
        return;
      }
    } catch (e) {
      debugPrint('Failed to save to external Documents: $e');
    }

    // Fallback: write to the app documents directory (private) if all external writes fail
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(pretty, flush: true);
      debugPrint('Session JSON saved to documents: ${file.path}');
    } catch (e) {
      debugPrint('Failed to save session JSON to documents: $e');
    }
  }
  
  int get numOfGames {
    return currentSession?.games.length ?? 1;
  }

  void setActiveGame(int gameIndex) {
    notifyListeners(); 
  }
}

