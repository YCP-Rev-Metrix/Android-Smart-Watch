import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/session.dart';
import '../models/game.dart';
import '../models/frame.dart';
import '../models/shot.dart';
import '../controllers/ble_manager.dart';

/// Test utility for BLE packet transmission
/// 
/// This creates a sample GameSession and sends it over BLE so you can verify
/// the transmission in the phone's logcat.
class BLEPacketTestUtil {
  /// Create a realistic test session with multiple frames and shots
  static GameSession createTestSession() {
    var session = GameSession.newSession('TEST_SESSION_${DateTime.now().millisecondsSinceEpoch}');
    var game = session.games.first;
    
    // Build frames with shots (need to use copyWithShot because Frame is immutable)
    final updatedFrames = <Frame>[];
    
    for (int frameNum = 0; frameNum < 3; frameNum++) {
      var frame = game.frames[frameNum];
      
      // Add 1-2 shots depending on frame
      for (int shotNum = 0; shotNum < (frameNum == 0 ? 1 : 2); shotNum++) {
        // Build leave type bitmask: first shot knocks down some pins, second shot different pins
        final List<bool> standingPins = List.filled(10, true);
        for (int i = 0; i < 5 + shotNum; i++) {
          if (i < standingPins.length) {
            standingPins[i] = false; // Pin knocked down
          }
        }
        final leaveType = Shot.buildLeaveType(
          standingPins: standingPins,
          isFoul: false,
        );
        
        final shot = Shot(
          shotNumber: frameNum * 2 + shotNum + 1,
          ball: 1,
          count: 5 + shotNum, // Pins knocked down
          leaveType: leaveType,
          position: 'pocket',
          timestamp: DateTime.now().add(Duration(minutes: frameNum * 2, seconds: shotNum * 30)),
          speed: 15.5 + (shotNum * 0.5),
          hitBoard: 18,
        );
        
        frame = frame.copyWithShot(shot);
      }
      
      updatedFrames.add(frame);
    }
    
    // Replace the frames in the game
    game = Game(
      gameNumber: game.gameNumber,
      score: game.score,
      startingLane: game.startingLane,
      lanes: game.lanes,
      frames: [...game.frames.sublist(0, 3).asMap().entries.map((e) => updatedFrames[e.key]).toList(), ...game.frames.sublist(3)],
    );
    
    // Replace the game in the session
    session = GameSession(
      sessionId: session.sessionId,
      startTime: session.startTime,
      endTime: session.endTime,
      isComplete: session.isComplete,
      numOfGames: session.numOfGames,
      balls: session.balls,
      games: [game, ...session.games.skip(1)],
    );
    
    return session;
  }
  
  /// Create a minimal test session (good for quick testing)
  static GameSession createMinimalTestSession() {
    var session = GameSession.newSession('MINIMAL_TEST_${DateTime.now().millisecondsSinceEpoch}');
    var game = session.games.first;
    var frame = game.frames[0];
    
    final leaveType = Shot.buildLeaveType(
      standingPins: List.filled(10, false), // All pins down (strike)
      isFoul: false,
    );
    
    final shot = Shot(
      shotNumber: 1,
      ball: 1,
      count: 10,
      leaveType: leaveType,
      position: 'pocket',
      timestamp: DateTime.now(),
      speed: 15.0,
      hitBoard: 18,
    );
    
    frame = frame.copyWithShot(shot);
    
    // Update game with new frame
    game = Game(
      gameNumber: game.gameNumber,
      score: game.score,
      startingLane: game.startingLane,
      lanes: game.lanes,
      frames: [frame, ...game.frames.skip(1)],
    );
    
    // Update session with new game
    session = GameSession(
      sessionId: session.sessionId,
      startTime: session.startTime,
      endTime: session.endTime,
      isComplete: session.isComplete,
      numOfGames: session.numOfGames,
      balls: session.balls,
      games: [game],
    );
    
    return session;
  }
}

/// Test widget that displays transmission status and button to send test data
class BLEPacketTestWidget extends StatefulWidget {
  final bool useMinimalSession;
  
  const BLEPacketTestWidget({
    Key? key,
    this.useMinimalSession = false,
  }) : super(key: key);

  @override
  State<BLEPacketTestWidget> createState() => _BLEPacketTestWidgetState();
}

class _BLEPacketTestWidgetState extends State<BLEPacketTestWidget> {
  final BLEManager _ble = Get.find<BLEManager>();
  bool _isSending = false;
  
  Future<void> _sendTestData(bool minimal) async {
    setState(() {
      _isSending = true;
    });
    
    print('📤 [BLE Test] Button pressed, minimal=$minimal');
    
    try {
      print('📤 [BLE Test] Creating session...');
      final session = minimal
          ? BLEPacketTestUtil.createMinimalTestSession()
          : BLEPacketTestUtil.createTestSession();
      
      print('📤 [BLE Test] Session created:');
      print('   Session ID: ${session.sessionId}');
      print('   Games: ${session.games.length}');
      print('   Balls: ${session.balls}');
      
      print('📤 [BLE Test] Converting to JSON...');
      final json = session.toJson();
      print('📤 [BLE Test] JSON created, calling sendJsonInChunks...');
      
      await _ble.sendJsonInChunks(json);
      
      print('📤 [BLE Test] Transmission complete!');
    } catch (e) {
      print('❌ [BLE Test] Error: $e');
      print(e);
    } finally {
      setState(() => _isSending = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isSending ? null : () => _sendTestData(true),
              child: const Text('Minimal'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSending ? null : () => _sendTestData(false),
              child: const Text('Full'),
            ),
          ],
        ),
      ),
    );
  }
}
