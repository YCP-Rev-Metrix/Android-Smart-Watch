// lib/controllers/session_controller.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/frame.dart';
import '../models/shot.dart';
import '../models/account_packet.dart';
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



  static Game createEmpty(int gameNumber, {int? incomingScore, int startingFrameIndex = 0}) {
    return Game(
      gameNumber: gameNumber,
      frames: List.generate(12, (i) => Frame(frameNumber: i + 1, lane: 1)),
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

  // _activeFrameIndex: 0-9 for the 10 main frames. Set to 10 for game over.
  int _activeFrameIndex = 0;
  // _activeShotIndex: 1, 2, or 3 (for the 10th frame)
  int _activeShotIndex = 1; 

  // Per-game tracking: stores frame/shot index for each game
  Map<int, int> gameFrameIndex = {}; // gameIndex -> frameIndex
  Map<int, int> gameShotIndex = {}; // gameIndex -> shotIndex

  int get activeFrameIndex => _activeFrameIndex; 
  int get activeShotIndex => _activeShotIndex; 

  // Default selections for new shots
  int defaultLane = 1;
  double defaultBoard = 17.0;
  int defaultBall = 3;
  double defaultSpeed = 15.5;
  
  // Per-lane stance defaults (lane 1 and lane 2)
  Map<int, double> defaultStanceByLane = {1: 20.0, 2: 20.0};
  Map<int, double> defaultTargetByLane = {1: 20.0, 2: 20.0};
  Map<int, double> defaultBreakPointByLane = {1: 20.0, 2: 20.0};

  /// Helper to create test shots (for manual testing/debugging only)
  Shot _createTestShot({
    required int shotNumber,
    required int count,
    required List<bool> standingPins,
    bool isFoul = false,
    int frameNum = 1,
    int lane = 1,
    double stance = 20.0,
  }) {
    final pins = Shot.buildPins(standingPins: standingPins, isFoul: isFoul);
    return Shot(
      shotNumber: shotNumber,
      ball: defaultBall,
      numOfPinsKnocked: count,
      pins: pins,
      impact: 12 + (shotNumber % 5),
      stance: stance,
      target: 20.0,
      breakPoint: 20.0,
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
    
    // Initialize per-game tracking
    gameFrameIndex.clear();
    gameShotIndex.clear();
    for (int gameIdx = 0; gameIdx < currentGameCount; gameIdx++) {
      gameFrameIndex[gameIdx] = 0;
      gameShotIndex[gameIdx] = 1;
    }
    
    notifyListeners(); 
  }

  void recordShot({
    required int lane,
    required double speed,
    required double impact,
    required int ball,
    required double stance,
    required double target,
    required double breakPoint,
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

    // Check for game over state (frames 0-11 are valid, so allow up to index 11)
    if (activeGame == null || activeFrameIndexForUpdate >= 12) return;

    final oldFrame = activeGame.frames[activeFrameIndexForUpdate];

    // 2. Create the new Shot object
    final newShot = Shot(
      shotNumber: oldFrame.shots.length,  // 0-based: 0 for first, 1 for second
      ball: ball,
      numOfPinsKnocked: pinsDownCount,
      pins: Shot.buildPins(standingPins: standingPins, isFoul: isFoul),
      impact: impact,
      stance: stance,
      target: target,
      breakPoint: breakPoint,
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
    defaultBoard = impact;
    defaultBall = ball;
    defaultStanceByLane[lane] = stance;
    defaultTargetByLane[lane] = target;
    defaultBreakPointByLane[lane] = breakPoint;

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
      
      // Encode shot to binary packet
      final packet = shot.encodeToBinary(
        sessionId: activeSessionId,
        gameNumber: gameNumber,
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
  // Frame 10: Strike=1 shot (enables 11), Non-strike=2 shots
  // Frame 11: Strike=1 shot (enables 12), Non-strike=2 shots
  // Frame 12: Only 1 shot max
  void _advanceFrameAndShot(Frame newFrame) {
    final frameNumber = newFrame.frameNumber;
    final shotCount = newFrame.shots.length;
    
    // Frames 1-9 (index 0-8): Normal logic - strike ends frame, non-strike needs 2 shots
    if (frameNumber < 10) {
      if (newFrame.isComplete) {
        _activeFrameIndex++;
        _activeShotIndex = 1;
      } else {
        _activeShotIndex = 2;
      }
    }
    // Frame 10 (index 9)
    else if (frameNumber == 10) {
      if (shotCount == 1) {
        final firstShot = newFrame.shots.first;
        if (firstShot.numOfPinsKnocked == 10) {
          // Strike on shot 1 - frame 10 is done, move to frame 11
          _activeFrameIndex++;
          _activeShotIndex = 1;
        } else {
          // Not a strike, need shot 2
          _activeShotIndex = 2;
        }
      } else if (shotCount == 2) {
        // Two shots taken in frame 10
        final totalPins = newFrame.totalPinsDown;
        if (totalPins >= 10) {
          // Spare achieved, move to frame 11
          _activeFrameIndex++;
          _activeShotIndex = 1;
        }
        // GAME END: Open frame (less than 10 pins) - don't advance
        // Frame page stays on frame 10, shot 2 (LAST SHOT SCENARIO #1)
      }
    }
    // Frame 11 (index 10) - only exists if frame 10 was a strike or spare
    else if (frameNumber == 11) {
      final frame10 = currentSession?.games[activeGameIndex].frames[9];
      final wasFrame10Strike = frame10?.shots.first.numOfPinsKnocked == 10;
      final wasFrame10Spare = frame10 != null && frame10.shots.length >= 2 && frame10.totalPinsDown >= 10 && !wasFrame10Strike;
      
      if (shotCount == 1) {
        final firstShot = newFrame.shots.first;
        
        // If frame 10 was a spare, game ends after 1 shot in frame 11
        if (wasFrame10Spare) {
          // GAME END: Frame 10 was spare, frame 11 is done after 1 shot
          _activeShotIndex = 1; // Explicitly keep at shot 1
        } else if (firstShot.numOfPinsKnocked == 10) {
          // Strike on shot 1 - move to frame 12 (if frame 10 was also strike)
          if (wasFrame10Strike) {
            // Both strikes - move to frame 12
            _activeFrameIndex++;
            _activeShotIndex = 1;
          } else {
            // Single strike in frame 11 (frame 10 was something else) - game ends
            _activeShotIndex = 1;
          }
        } else {
          // Not a strike on shot 1, need shot 2 (only possible if frame 10 was strike)
          _activeShotIndex = 2;
        }
      } else if (shotCount == 2) {
        // Two shots taken in frame 11 - game ends (only possible if frame 10 was strike)
        // Don't advance (LAST SHOT SCENARIO #2)
      }
    }
    // Frame 12 (index 11) - only exists if frame 11 was a strike or spare
    else if (frameNumber == 12) {
      if (shotCount == 1) {
        // GAME END: Frame 12 is the last possible shot
        // Explicitly set shot index to 1 to keep state consistent
        _activeShotIndex = 1;
        // Don't advance - keep showing frame 12, shot 1 (LAST SHOT SCENARIO #3)
      }
    }
    
    // Save the updated frame/shot to per-game tracking
    gameFrameIndex[activeGameIndex] = _activeFrameIndex;
    gameShotIndex[activeGameIndex] = _activeShotIndex;
  }
  
  /// Edits an existing shot in a frame by replacing the Shot object at a specific index.
  void editShot({
    required int frameIndex,
    required int shotIndexInFrame,
    required int lane,
    required double speed,
    required double impact,
    required int ball,
    required double stance,
    required double target,
    required double breakPoint,
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
          impact: impact,
          stance: stance,
          target: target,
          breakPoint: breakPoint,
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
        defaultTargetByLane[lane] = target;
        defaultBreakPointByLane[lane] = breakPoint;
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
    // Save current game's frame/shot state before switching
    gameFrameIndex[activeGameIndex] = _activeFrameIndex;
    gameShotIndex[activeGameIndex] = _activeShotIndex;
    
    // Switch to new game
    activeGameIndex = gameIndex;
    currentGameNumber = gameIndex + 1; // Convert 0-based index to 1-based game number
    
    // Restore the new game's frame/shot state (or use defaults for new games)
    _activeFrameIndex = gameFrameIndex[gameIndex] ?? 0;
    _activeShotIndex = gameShotIndex[gameIndex] ?? 1;
    
    print('WATCH: Switched to game $gameIndex -> Shot $_activeShotIndex, gameShotIndex[$gameIndex] = ${gameShotIndex[gameIndex]}');
    
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
    List<GameState>? gameStates, // New: per-game state data
  }) {
    activeSessionId = sessionId;
    activeBalls = balls;
    activeGameIndex = (gameNumber - 1).clamp(0, 9);
    currentGameNumber = gameNumber;
    currentGameCount = gameCount.clamp(1, 10);
    _activeFrameIndex = (frameNumber - 1).clamp(0, 11);
    _activeShotIndex = shotNumber.clamp(1, 3);
    
    // Calculate starting frame index
    final startingFrameIdx = (frameNumber - 1).clamp(0, 11);
    
    // Create a fresh session with empty games
    final newGames = List.generate(currentGameCount, (gameIdx) {
      final frameIdx = (gameIdx == activeGameIndex) ? startingFrameIdx : 0;
      return Game.createEmpty(gameIdx + 1, incomingScore: 0, startingFrameIndex: frameIdx);
    });
    
    // Initialize per-game tracking for all games
    gameFrameIndex.clear();
    gameShotIndex.clear();
    
    // If gameStates provided, use per-game data; otherwise use backward compatibility
    if (gameStates != null && gameStates.isNotEmpty) {
      // Set up each game based on gameStates array
      for (int gameIdx = 0; gameIdx < gameStates.length && gameIdx < currentGameCount; gameIdx++) {
        final gs = gameStates[gameIdx];
        final frameIdx = (gs.frameNumber - 1).clamp(0, 11);
        final shotIdx = gs.shotNumber.clamp(1, 3);
        
        gameFrameIndex[gameIdx] = frameIdx;
        gameShotIndex[gameIdx] = shotIdx;
        
        // For ALL games on shot 2+, add read-only shot with previous pins
        if (shotIdx >= 2 && gs.previousPins > 0) {
          print('WATCH: Game ${gameIdx + 1} adding read-only shot (shotIdx=$shotIdx, previousPins=0x${gs.previousPins.toRadixString(16)})');
          final activeGame = newGames[gameIdx];
          final currentFrame = activeGame.frames[frameIdx];
          
          // Convert previousPins bitmask to List<bool>
          final previousPinsStanding = List.filled(10, false);
          for (int i = 0; i < 10; i++) {
            if ((gs.previousPins & (1 << i)) != 0) {
              previousPinsStanding[i] = true;
            }
          }
          
          final readOnlyShot = Shot.readOnlyDefault(
            frameNum: gs.frameNumber,
            lane: currentFrame.lane,
            standingPins: previousPinsStanding,
          );
          
          // Check if previous shot was a strike
          if (readOnlyShot.numOfPinsKnocked == 10) {
            // Strike - move to next frame
            gameFrameIndex[gameIdx] = (frameIdx + 1).clamp(0, 11);
            gameShotIndex[gameIdx] = 1;
          } else {
            // Not a strike - add read-only shot to current frame
            final updatedFrame = Frame(
              frameNumber: currentFrame.frameNumber,
              lane: currentFrame.lane,
              shots: [readOnlyShot],
            );
            final updatedGame = activeGame.copyWithFrame(
              index: frameIdx,
              newFrame: updatedFrame,
            );
            newGames[gameIdx] = updatedGame;
          }
        }
      }
      
      // Update active game state to match active game index
      _activeFrameIndex = gameFrameIndex[activeGameIndex] ?? 0;
      _activeShotIndex = gameShotIndex[activeGameIndex] ?? 1;
      
      print('WATCH: After gameStates - gameShotIndex map: $gameShotIndex');
      print('WATCH: Active game $activeGameIndex set to Shot $_activeShotIndex');
    } else {
      // Backward compatibility: old single-game initialization
      for (int gameIdx = 0; gameIdx < currentGameCount; gameIdx++) {
        if (gameIdx == activeGameIndex) {
          gameFrameIndex[gameIdx] = _activeFrameIndex;
          gameShotIndex[gameIdx] = _activeShotIndex;
        } else {
          gameFrameIndex[gameIdx] = 0;
          gameShotIndex[gameIdx] = 1;
        }
      }
      
      // Handle read-only shot for active game
      if (shotNumber >= 2 && previousPinsStanding != null) {
        final activeGame = newGames[activeGameIndex];
        final currentFrame = activeGame.frames[_activeFrameIndex];
        
        final readOnlyShot = Shot.readOnlyDefault(
          frameNum: frameNumber,
          lane: currentFrame.lane,
          standingPins: previousPinsStanding,
        );
        
        if (readOnlyShot.numOfPinsKnocked == 10) {
          _activeFrameIndex = (_activeFrameIndex + 1).clamp(0, 11);
          _activeShotIndex = 1;
          gameFrameIndex[activeGameIndex] = _activeFrameIndex;
          gameShotIndex[activeGameIndex] = _activeShotIndex;
        } else {
          final updatedFrame = Frame(
            frameNumber: currentFrame.frameNumber,
            lane: currentFrame.lane,
            shots: [readOnlyShot],
          );
          final updatedGame = activeGame.copyWithFrame(
            index: _activeFrameIndex,
            newFrame: updatedFrame,
          );
          newGames[activeGameIndex] = updatedGame;
        }
      }
    }
    
    currentSession = SessionModel(games: newGames);
    notifyListeners();
  }

  void initializeAnonymous({List<Ball> balls = const []}) {
    // Anonymous session: same as a normal session, but with a random session ID
    // above 100,000 so the phone knows it wasn't pre-created. Still has access to user's balls and info.
    activeSessionId = Random().nextInt(0xFFFFFFFF - 100000) + 100000;
    activeBalls = balls;
    activeGameIndex = 0;
    currentGameNumber = 1;
    currentGameCount = 1;
    _activeFrameIndex = 0;
    _activeShotIndex = 1;
    
    // Create a fresh empty session with 1 game
    final newGames = [
      Game.createEmpty(1, incomingScore: 0),
    ];
    currentSession = SessionModel(games: newGames);
    
    // Initialize per-game tracking
    gameFrameIndex.clear();
    gameShotIndex.clear();
    gameFrameIndex[0] = 0;
    gameShotIndex[0] = 1;
    
    notifyListeners();
  }
}

