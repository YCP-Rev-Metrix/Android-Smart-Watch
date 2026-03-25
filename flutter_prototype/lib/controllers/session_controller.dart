// lib/controllers/session_controller.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/frame.dart';
import '../models/shot.dart';
import '../models/account_packet.dart';
import '../utils/bowling_scorer.dart';
import './ble_manager.dart'; 

// ----------------------------------------------------------------------
// 1. Core Model Structure 
// ----------------------------------------------------------------------

class Game {
  final int gameNumber;
  final List<Frame> frames;
  final int? incomingScore; // Score from the phone (used as reference)
  final int startingFrameIndex; // which frame index (0-based) the phone was on when session started

  Game({required this.gameNumber, required this.frames, this.incomingScore, this.startingFrameIndex = 0});

  /// Calculate the total score based on frames and incoming score
  int get totalScore => BowlingScorer.calculateGameScore(frames, incomingScore: incomingScore, startingFrameIndex: startingFrameIndex);

  static Game createEmpty(int gameNumber, {int? incomingScore, int startingFrameIndex = 0}) {
    return Game(
      gameNumber: gameNumber,
      frames: List.generate(10, (i) => Frame(frameNumber: i + 1, lane: 1)),
      incomingScore: incomingScore,
      startingFrameIndex: startingFrameIndex,
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
      incomingScore: incomingScore,
      startingFrameIndex: startingFrameIndex,
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
    return _instance;
  }
  SessionController._internal();

  SessionModel? currentSession;

  // Session context from account packet
  int activeSessionId = 0;
  List<Ball> activeBalls = const [];
  int activeGameIndex = 0; // 0-based index into currentSession.games
  int currentGameNumber = 1; // Current game number from packet (1-based)
  int currentGameCount = 1; // Total number of games in this session
  int currentGameScore = 0; // Current game's score from packet

  // _activeFrameIndex: 0-9 for the 10 main frames. Set to 10 for game over.
  int _activeFrameIndex = 0;
  // _activeShotIndex: 1, 2, or 3 (for the 10th frame)
  int _activeShotIndex = 1; 

  int get activeFrameIndex => _activeFrameIndex; 
  int get activeShotIndex => _activeShotIndex; 

  // Default selections for new shots
  int defaultLane = 1;
  int defaultBoard = 0; // 0-based index: 0=Right
  int defaultBall = 3;
  double defaultSpeed = 15.5;
  
  // Per-lane stance defaults (lane 1 and lane 2)
  Map<int, int> defaultStanceByLane = {1: 20, 2: 20};

  /// Helper to create test shots (for manual testing/debugging only)
  Shot _createTestShot({
    required int shotNumber,
    required int count,
    required List<bool> standingPins,
    bool isFoul = false,
    int frameNum = 1,
    int lane = 1,
    int stance = 20,
  }) {
    final pins = Shot.buildPins(standingPins: standingPins, isFoul: isFoul);
    return Shot(
      shotNumber: shotNumber,
      ball: defaultBall,
      numOfPinsKnocked: count,
      pins: pins,
      board: 12 + (shotNumber % 5),
      stance: stance,
      speed: defaultSpeed + (shotNumber % 3) * 0.1,
      frameNum: frameNum,
      lane: lane,
    );
  }

  /// Create a list of empty games with optional test scores (for manual testing/debugging only)
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
      
      return Game.createEmpty(gameIndex + 1, incomingScore: testScore);
    });
  }

  /// Manually initialize test data (for manual testing/debugging only - NOT called automatically)
  void _initializeTestData() {
    int globalShotCount = 1;
    final List<Frame> detailedFrames = [];

    // --- Frame 1 (Index 0): Strike (X) - Cumulative Score: 30 ---
    final shot1 = _createTestShot(
      shotNumber: globalShotCount++,
      count: 10,
      standingPins: List.filled(10, false),
      frameNum: 1,
      lane: 1,
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
      frameNum: 2,
      lane: 2,
    );
    final shot3 = _createTestShot(
      shotNumber: globalShotCount++,
      count: 3,
      standingPins: List.filled(10, false),
      frameNum: 2,
      lane: 2,
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
      frameNum: 3,
      lane: 1,
    );
    final shot5 = _createTestShot(
      shotNumber: globalShotCount++,
      count: 1,
      standingPins: [false, true, false, false, false, false, false, false, false, false],
      frameNum: 3,
      lane: 1,
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

    // Create the Game object
    final testGame = Game(
      gameNumber: 1,
      frames: [...detailedFrames, ...emptyFrames],
      incomingScore: 59, 
    );
    
    // Create additional test games
    final simpleGames = _createSimpleTestGames(6); 
    currentSession = SessionModel(
      games: [testGame, ...simpleGames], 
    );
    
    // Set active input position
    _activeFrameIndex = 3; 
    _activeShotIndex = 1;
  }

  /// Manually create a new session with test data (for manual testing/debugging only - NOT called automatically)
  void createNewSession({int numOfGames = 3}) {
    final newGames = _createSimpleTestGames(numOfGames);
    createNewSessionFromPacket(newGames);
  }

  void createNewSessionFromPacket(List<Game> parsedGames) {
    currentSession = SessionModel(games: parsedGames);
    currentGameCount = parsedGames.length; // Update game count to match new session
    _activeFrameIndex = 0;
    _activeShotIndex = 1;
    notifyListeners(); 
  }

  void recordShot({
    required int lane,
    required double speed,
    required int board,
    required int ball,
    required int stance,
    required List<bool> standingPins,
    required int pinsDownCount,
    required bool isFoul,
  }) {
    // 1. Find the active Game and Frame
    final activeGame = (currentSession != null && activeGameIndex < currentSession!.games.length)
        ? currentSession!.games[activeGameIndex]
        : null;
    // Use the stored active index
    final activeFrameIndexForUpdate = _activeFrameIndex;

    // Check for game over state
    if (activeGame == null || activeFrameIndexForUpdate >= 10) return;

    final oldFrame = activeGame.frames[activeFrameIndexForUpdate];

    // 2. Create the new Shot object
    final newShot = Shot(
      shotNumber: oldFrame.shots.length,  // 0-based: 0 for first, 1 for second
      ball: ball,
      numOfPinsKnocked: pinsDownCount,
      pins: Shot.buildPins(standingPins: standingPins, isFoul: isFoul),
      board: board,
      stance: stance,
      speed: speed,
      frameNum: oldFrame.frameNumber,
      lane: lane,
    );

    // 3. Create the new Frame (immutable update)
    final newFrame = Frame(
        frameNumber: oldFrame.frameNumber,
        lane: lane,
        shots: [...oldFrame.shots, newShot],
    );
    
    // 4. Create the new Game (immutable update)
    final newGame = activeGame.copyWithFrame(index: activeFrameIndexForUpdate, newFrame: newFrame);
    
    // 5. Update the session - replace the game at activeGameIndex
    final updatedGames = List<Game>.from(currentSession!.games);
    updatedGames[activeGameIndex] = newGame;
    currentSession = SessionModel(games: updatedGames);

    _advanceFrameAndShot(newFrame);

    // Persist the user's last selections as global defaults for subsequent shots
    defaultLane = lane;
    defaultSpeed = speed;
    defaultBoard = board;
    defaultBall = ball;
    defaultStanceByLane[lane] = stance;

    // 6. Send shot packet to phone via BLE
    _sendShotPacket(newShot, activeGame.gameNumber, newFrame.shots.length);

    notifyListeners();
  }

  /// Sends the recorded shot to the phone via BLE
  Future<void> _sendShotPacket(Shot shot, int gameNumber, int shotIndexInFrame) async {
    try {
      // Get the active game to access its total score
      final activeGame = (currentSession != null && activeGameIndex < currentSession!.games.length)
          ? currentSession!.games[activeGameIndex]
          : null;
      
      if (activeGame == null) return;
      
      // Encode shot to binary packet with game score
      final packet = shot.encodeToBinary(
        sessionId: activeSessionId,
        gameNumber: gameNumber,
        gameScore: activeGame.totalScore,
        shotIndexInFrame: shotIndexInFrame,
      );

      // Log the packet
      final hexPacket = packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
      print('WATCH SESSION: Sending shot packet (${packet.length} bytes):');
      print('WATCH SESSION Packet hex: $hexPacket');
      print('WATCH SESSION Details - SessionId: $activeSessionId, Game: $gameNumber, Frame: ${shot.frameNum}, Shot: $shotIndexInFrame');

      // Send via BLEManager
      final bleManager = Get.find<BLEManager>();
      await bleManager.sendRawBLEPacket(packet);

      print('WATCH SESSION: Shot packet sent to phone successfully');
    } catch (e) {
      print('WATCH SESSION ERROR: Failed to send shot packet: $e');
    }
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
    required int board,
    required int ball,
    required int stance,
    required List<bool> standingPins,
    required int pinsDownCount,
    required bool isFoul,
  }) {
    final activeGame = (currentSession != null && activeGameIndex < currentSession!.games.length)
        ? currentSession!.games[activeGameIndex]
        : null;

    if (activeGame != null && frameIndex >= 0 && frameIndex < activeGame.frames.length) {
      final oldFrame = activeGame.frames[frameIndex];
      final oldShots = oldFrame.shots;

      if (shotIndexInFrame >= 0 && shotIndexInFrame < oldShots.length) {
        final oldShot = oldShots[shotIndexInFrame];
        
        // 1. Create the new Shot object, maintaining the original shotNumber
        final updatedShot = Shot(
          shotNumber: oldShot.shotNumber,
          ball: ball,
          numOfPinsKnocked: pinsDownCount,
          pins: Shot.buildPins(standingPins: standingPins, isFoul: isFoul),
          board: board,
          stance: stance,
          speed: speed,
          frameNum: oldFrame.frameNumber,
          lane: lane,
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
        
        // 5. Update the session - replace the game at activeGameIndex
        final updatedGames = List<Game>.from(currentSession!.games);
        updatedGames[activeGameIndex] = newGame;
        currentSession = SessionModel(games: updatedGames);
        
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
          for (final line in prettyEdit.split('\n')) {
            debugPrint(line);
          }
          _saveSessionJsonToDocuments(prettyEdit, filename: 'RevMetrix.json');
        } catch (e, st) {
          debugPrint('Failed to build session JSON after edit: $e\n$st');
        }
        // Persist stance per lane when editing
        defaultStanceByLane[lane] = stance;
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
    activeGameIndex = gameIndex;
    currentGameNumber = gameIndex + 1; // Convert 0-based index to 1-based game number
    notifyListeners();
  }

  void initializeFromPacket({
    required int sessionId,
    required int gameNumber,
    required int frameNumber,
    required int shotNumber,
    required List<Ball> balls,
    List<bool>? previousPinsStanding,
    int gameCount = 1,
    int gameScore = 0,
  }) {
    activeSessionId = sessionId;
    activeBalls = balls;
    activeGameIndex = (gameNumber - 1).clamp(0, 9);
    currentGameNumber = gameNumber;
    currentGameCount = gameCount.clamp(1, 10);
    currentGameScore = gameScore;
    _activeFrameIndex = (frameNumber - 1).clamp(0, 9);
    _activeShotIndex = shotNumber.clamp(1, 3); // shotNumber: 1-based (1=shot1, 2=shot2)
    
    // Calculate starting frame index: frames on the phone don't need to be calculated locally
    final startingFrameIdx = (frameNumber - 1).clamp(0, 9); // Skip frames before the current one
    
    // Create a fresh session with empty games
    final newGames = List.generate(currentGameCount, (gameIdx) {
      final score = (gameIdx == activeGameIndex) ? gameScore : 0;
      final frameIdx = (gameIdx == activeGameIndex) ? startingFrameIdx : 0;
      return Game.createEmpty(gameIdx + 1, incomingScore: score, startingFrameIndex: frameIdx);
    });
    
    // If shot 2 or higher, create read-only shot 1 with previous pins on the active frame
    if (shotNumber >= 2 && previousPinsStanding != null) {
      final activeGame = newGames[activeGameIndex];
      final currentFrame = activeGame.frames[_activeFrameIndex];
      
      final readOnlyShot = Shot.readOnlyDefault(
        frameNum: frameNumber,
        lane: currentFrame.lane,
        standingPins: previousPinsStanding,
      );
      
      // Create updated frame with the read-only shot
      final updatedFrame = Frame(
        frameNumber: currentFrame.frameNumber,
        lane: currentFrame.lane,
        shots: [readOnlyShot],
      );
      
      // Update the game with the new frame
      final updatedGame = activeGame.copyWithFrame(
        index: _activeFrameIndex,
        newFrame: updatedFrame,
      );
      newGames[activeGameIndex] = updatedGame;
    }
    
    currentSession = SessionModel(games: newGames);
    
    notifyListeners();
  }

  void initializeAnonymous() {
    // Use a high reserved session ID (0xFFFFFFFF) so phone knows this is an anonymous/test session
    // Phone can recognize this and handle appropriately (not associated with any stored session)
    activeSessionId = 0xFFFFFFFF;
    activeBalls = const [];
    activeGameIndex = 0;
    _activeFrameIndex = 0;
    _activeShotIndex = 1;
    
    // Create a fresh empty session with 1 game
    final newGames = [
      Game.createEmpty(1, incomingScore: 0),
    ];
    currentSession = SessionModel(games: newGames);
    
    notifyListeners();
  }
}

