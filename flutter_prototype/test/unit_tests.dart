import 'package:flutter_test/flutter_test.dart';
import 'package:watch_app/models/shot.dart';
import 'package:watch_app/models/frame.dart';
import 'package:watch_app/models/game.dart';
import 'package:watch_app/models/session.dart';
import 'package:watch_app/models/ble_packet.dart';
import 'dart:convert';

void main() {
  group('Shot Model Tests', () {
    test('Shot creation with valid data', () {
      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 10,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      expect(shot.shotNumber, 1);
      expect(shot.count, 10);
      expect(shot.ball, 1);
      expect(shot.speed, 15.5);
    });

    test('Shot pinsStanding calculation', () {
      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 7,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      expect(shot.pinsStanding, 3); // 10 - 7 = 3
    });

    test('Shot buildLeaveType for strike', () {
      final standingPins = List.filled(10, false); // All pins down
      final leaveType = Shot.buildLeaveType(standingPins: standingPins, isFoul: false);

      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 10,
        leaveType: leaveType,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      expect(shot.isFoul, false);
    });

    test('Shot buildLeaveType with foul', () {
      final standingPins = List.filled(10, true); // All pins standing
      final leaveType = Shot.buildLeaveType(standingPins: standingPins, isFoul: true);

      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 0,
        leaveType: leaveType,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      expect(shot.isFoul, true);
    });

    test('Shot pinsState decoding', () {
      final standingPins = [true, true, false, false, true, false, false, false, false, false];
      final leaveType = Shot.buildLeaveType(standingPins: standingPins, isFoul: false);

      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 6,
        leaveType: leaveType,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      expect(shot.pinsState, standingPins);
    });

    test('Shot toJson and fromJson roundtrip', () {
      final originalShot = Shot(
        shotNumber: 5,
        ball: 2,
        count: 8,
        leaveType: 123,
        position: 'left',
        timestamp: DateTime(2025, 12, 10, 10, 30),
        speed: 18.5,
        hitBoard: 20,
      );

      final json = originalShot.toJson();
      final restoredShot = Shot.fromJson(json);

      expect(restoredShot.shotNumber, originalShot.shotNumber);
      expect(restoredShot.ball, originalShot.ball);
      expect(restoredShot.count, originalShot.count);
      expect(restoredShot.position, originalShot.position);
      expect(restoredShot.speed, originalShot.speed);
      expect(restoredShot.hitBoard, originalShot.hitBoard);
    });
  });

  group('Frame Model Tests', () {
    test('Frame creation with empty shots', () {
      final frame = Frame(frameNumber: 1, lane: 1);
      expect(frame.frameNumber, 1);
      expect(frame.shots.isEmpty, true);
      expect(frame.isComplete, false);
    });

    test('Frame isComplete with strike', () {
      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 10,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      final frame = Frame(frameNumber: 1, lane: 1).copyWithShot(shot);
      expect(frame.isComplete, true);
    });

    test('Frame isComplete with two shots', () {
      final shot1 = Shot(
        shotNumber: 1,
        ball: 1,
        count: 5,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );
      final shot2 = Shot(
        shotNumber: 2,
        ball: 1,
        count: 5,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      var frame = Frame(frameNumber: 1, lane: 1).copyWithShot(shot1);
      frame = frame.copyWithShot(shot2);

      expect(frame.isComplete, true);
    });

    test('Frame isComplete with one shot less than strike', () {
      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 9,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      final frame = Frame(frameNumber: 1, lane: 1).copyWithShot(shot);
      expect(frame.isComplete, false);
    });

    test('Frame totalPinsDown calculation', () {
      final shot1 = Shot(
        shotNumber: 1,
        ball: 1,
        count: 5,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );
      final shot2 = Shot(
        shotNumber: 2,
        ball: 1,
        count: 3,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      var frame = Frame(frameNumber: 1, lane: 1).copyWithShot(shot1);
      frame = frame.copyWithShot(shot2);

      expect(frame.totalPinsDown, 8);
    });

    test('Frame copyWithShot immutability', () {
      final shot1 = Shot(
        shotNumber: 1,
        ball: 1,
        count: 5,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      final frame1 = Frame(frameNumber: 1, lane: 1);
      final frame2 = frame1.copyWithShot(shot1);

      expect(frame1.shots.isEmpty, true);
      expect(frame2.shots.length, 1);
    });

    test('Frame toJson and fromJson roundtrip', () {
      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 7,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10, 10, 30),
        speed: 15.5,
        hitBoard: 18,
      );

      var originalFrame = Frame(frameNumber: 3, lane: 2).copyWithShot(shot);

      final json = originalFrame.toJson();
      final restoredFrame = Frame.fromJson(json);

      expect(restoredFrame.frameNumber, 3);
      expect(restoredFrame.lane, 2);
      expect(restoredFrame.shots.length, 1);
      expect(restoredFrame.shots.first.shotNumber, 1);
    });
  });

  group('Game Model Tests', () {
    test('Game creation with newGame factory', () {
      final game = Game.newGame(1, startingLane: 3);
      expect(game.gameNumber, 1);
      expect(game.startingLane, 3);
      expect(game.frames.length, 12);
      expect(game.isComplete, false);
    });

    test('Game currentFrame returns first incomplete frame', () {
      final game = Game.newGame(1);
      final currentFrame = game.currentFrame;
      expect(currentFrame, isNotNull);
      expect(currentFrame!.frameNumber, 1);
    });

    test('Game isComplete with all frames complete', () {
      final game = Game.newGame(1);

      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 10,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      // Add shot to all frames to mark them complete
      for (int i = 0; i < game.frames.length; i++) {
        game.frames[i] = game.frames[i].copyWithShot(shot);
      }

      expect(game.isComplete, true);
    });

    test('Game toJson includes all frames', () {
      final game = Game.newGame(1);
      final json = game.toJson();

      expect(json['gameNumber'], 1);
      expect(json['frames'], isA<List>());
      expect((json['frames'] as List).length, 12);
    });
  });

  group('Session Model Tests', () {
    test('GameSession creation with newSession factory', () {
      final session = GameSession.newSession('SESSION_001');
      expect(session.sessionId, 'SESSION_001');
      expect(session.numOfGames, 1);
      expect(session.games.length, 1);
      expect(session.balls.length, 3); // Default balls
    });

    test('GameSession activeGame returns first game', () {
      final session = GameSession.newSession('SESSION_001');
      final activeGame = session.activeGame;
      expect(activeGame, isNotNull);
      expect(activeGame!.gameNumber, 1);
    });

    test('GameSession completeSession sets flags', () {
      var session = GameSession.newSession('SESSION_001');
      expect(session.isComplete, false);
      expect(session.endTime, isNull);

      session.completeSession();
      expect(session.isComplete, true);
      expect(session.endTime, isNotNull);
    });

    test('GameSession toJson and fromJson roundtrip', () {
      final originalSession = GameSession.newSession('SESSION_TEST');

      final json = originalSession.toJson();
      final restoredSession = GameSession.fromJson(json);

      expect(restoredSession.sessionId, 'SESSION_TEST');
      expect(restoredSession.numOfGames, 1);
      expect(restoredSession.games.length, 1);
    });
  });

  group('BLEPacket Model Tests', () {
    test('BLEPacket encode creates 23-byte array', () {
      final packet = BLEPacket(
        packetType: BLEPacket.PACKET_TYPE_DATA,
        totalPackets: 5,
        packetIndex: 0,
        payload: [1, 2, 3, 4, 5],
      );

      final encoded = packet.encode();
      expect(encoded.length, 23);
      expect(encoded[0], BLEPacket.PACKET_TYPE_DATA);
    });

    test('BLEPacket decode restores packet correctly', () {
      final originalPayload = [1, 2, 3, 4, 5];
      final packet = BLEPacket(
        packetType: BLEPacket.PACKET_TYPE_DATA,
        totalPackets: 5,
        packetIndex: 2,
        payload: originalPayload,
      );

      final encoded = packet.encode();
      final decoded = BLEPacket.decode(encoded);

      expect(decoded.packetType, BLEPacket.PACKET_TYPE_DATA);
      expect(decoded.totalPackets, 5);
      expect(decoded.packetIndex, 2);
    });

    test('BLEPacket buildFromSession chunks correctly', () {
      final session = GameSession.newSession('TEST');
      final packets = BLEPacket.buildFromSession(session);

      expect(packets.isNotEmpty, true);
      // Should have data packets + 1 end marker
      expect(packets.last.packetType, BLEPacket.PACKET_TYPE_END);
    });

    test('BLEPacket all data packets have correct type', () {
      final session = GameSession.newSession('TEST');
      final packets = BLEPacket.buildFromSession(session);

      // All packets except last should be data packets
      for (int i = 0; i < packets.length - 1; i++) {
        expect(packets[i].packetType, BLEPacket.PACKET_TYPE_DATA);
      }
    });
  });

  group('JSON Serialization Tests', () {
    test('Complex session serialization and deserialization', () {
      // Create a complex session with multiple frames and shots
      final session = GameSession.newSession('COMPLEX_TEST');
      final game = session.games.first;

      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 7,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10, 10, 30, 45),
        speed: 15.5,
        hitBoard: 18,
      );

      // Add shot to first frame
      game.frames[0] = game.frames[0].copyWithShot(shot);

      // Serialize and deserialize
      final jsonString = jsonEncode(session.toJson());
      final jsonMap = jsonDecode(jsonString);
      final restoredSession = GameSession.fromJson(jsonMap);

      expect(restoredSession.sessionId, session.sessionId);
      expect(restoredSession.games.first.frames[0].shots.first.shotNumber, 1);
    });
  });

  group('Edge Cases and Validation Tests', () {
    test('Shot with maximum count (10 pins)', () {
      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 10,
        leaveType: 0,
        position: 'pocket',
        timestamp: DateTime(2025, 12, 10),
        speed: 15.5,
        hitBoard: 18,
      );

      expect(shot.count, 10);
      expect(shot.pinsStanding, 0);
    });

    test('Shot with zero count (gutter)', () {
      final shot = Shot(
        shotNumber: 1,
        ball: 1,
        count: 0,
        leaveType: 1023, // All pins standing
        position: 'gutter',
        timestamp: DateTime(2025, 12, 10),
        speed: 0,
        hitBoard: 1,
      );

      expect(shot.count, 0);
      expect(shot.pinsStanding, 10);
    });

    test('Frame with maximum lane number', () {
      final frame = Frame(frameNumber: 10, lane: 40);
      expect(frame.lane, 40);
    });

    test('Game with multiple frames updated', () {
      final game = Game.newGame(1);

      for (int i = 0; i < 3; i++) {
        final shot = Shot(
          shotNumber: i + 1,
          ball: 1,
          count: 5,
          leaveType: 0,
          position: 'pocket',
          timestamp: DateTime(2025, 12, 10),
          speed: 15.5,
          hitBoard: 18,
        );
        game.frames[i] = game.frames[i].copyWithShot(shot);
      }

      expect(game.frames[0].shots.length, 1);
      expect(game.frames[1].shots.length, 1);
      expect(game.frames[2].shots.length, 1);
    });

    test('BLEPacket with large payload', () {
      final largePayload = List.generate(18, (i) => i % 256);
      final packet = BLEPacket(
        packetType: BLEPacket.PACKET_TYPE_DATA,
        totalPackets: 100,
        packetIndex: 50,
        payload: largePayload,
      );

      final encoded = packet.encode();
      expect(encoded.length, 23);

      final decoded = BLEPacket.decode(encoded);
      expect(decoded.payload, largePayload);
    });
  });
}
