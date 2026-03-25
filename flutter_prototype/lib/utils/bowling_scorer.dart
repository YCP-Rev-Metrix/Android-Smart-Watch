import '../models/frame.dart';
import '../models/shot.dart';

/// Bowling score calculator following standard USBC rules
class BowlingScorer {
  /// Calculate the total score for a game given a list of frames
  /// If the phone provides an incoming score, it's used as the base and new frames are added to it
  /// startingFrameIndex: which frame index the phone was on (0-based) - frames before this are from phone
  static int calculateGameScore(List<Frame> frames, {int? incomingScore, int startingFrameIndex = 0}) {
    if (frames.isEmpty) return incomingScore ?? 0;

    int totalScore = incomingScore ?? 0;
    
    // Only calculate frames from startingFrameIndex onwards (these are new frames on the watch)
    int newFramesScore = 0;

    // Process new frames 1-9 (indices startingFrameIndex to 8)
    for (int i = startingFrameIndex; i < 9 && i < frames.length; i++) {
      final frame = frames[i];

      if (frame.shots.isEmpty) {
        // Frame not yet started
        continue;
      }

      final firstShot = frame.shots.first;

      // Check for Strike
      if (firstShot.numOfPinsKnocked == 10) {
        newFramesScore += 10;
        newFramesScore += _getNextTwoShots(frames, i);
      }
      // Check for Spare (10 pins in 2 shots, not a foul)
      else if (frame.shots.length >= 2 &&
          !firstShot.isFoul &&
          !frame.shots[1].isFoul &&
          frame.totalPinsDown == 10) {
        newFramesScore += 10;
        newFramesScore += _getNextOneShot(frames, i);
      }
      // Open frame or incomplete
      else {
        newFramesScore += frame.totalPinsDown;
      }
    }

    // Frame 10 (index 9) - special handling
    if (frames.length > 9 && startingFrameIndex <= 9) {
      final frame10 = frames[9];
      if (frame10.shots.isNotEmpty) {
        // Frame 10: just add all pins knocked down (bonuses are included in shot setup)
        newFramesScore += frame10.totalPinsDown;
      }
    }

    return totalScore + newFramesScore;
  }

  /// Get the next 1 shot (bonus for spare)
  static int _getNextOneShot(List<Frame> frames, int currentFrameIndex) {
    if (currentFrameIndex + 1 >= frames.length) return 0;

    final nextFrame = frames[currentFrameIndex + 1];
    if (nextFrame.shots.isEmpty) return 0;

    return nextFrame.shots.first.numOfPinsKnocked;
  }

  /// Get the next 2 shots (bonus for strike)
  static int _getNextTwoShots(List<Frame> frames, int currentFrameIndex) {
    int bonus = 0;

    if (currentFrameIndex + 1 >= frames.length) return 0;

    final nextFrame = frames[currentFrameIndex + 1];
    if (nextFrame.shots.isEmpty) return 0;

    // First shot of next frame
    bonus += nextFrame.shots.first.numOfPinsKnocked;

    // If next frame is also a strike, the second shot comes from frame after
    if (nextFrame.shots.first.numOfPinsKnocked == 10) {
      if (currentFrameIndex + 2 < frames.length) {
        final frameAfter = frames[currentFrameIndex + 2];
        if (frameAfter.shots.isNotEmpty) {
          bonus += frameAfter.shots.first.numOfPinsKnocked;
        }
      }
    } else if (nextFrame.shots.length >= 2) {
      // Second shot of next frame
      bonus += nextFrame.shots[1].numOfPinsKnocked;
    }

    return bonus;
  }

  /// Check if the game is incomplete (helps determine if we should use incoming score)
  static bool _isGameIncomplete(List<Frame> frames) {
    return frames.length < 10 ||
        (frames.length == 10 && !frames[9].isComplete);
  }

  /// Calculate all frame scores (cumulative) for display/debugging
  static List<int> calculateFrameScores(List<Frame> frames) {
    List<int> frameTotals = [];
    int cumulativeScore = 0;

    for (int i = 0; i < 9 && i < frames.length; i++) {
      final frame = frames[i];

      if (frame.shots.isEmpty) {
        frameTotals.add(cumulativeScore);
        continue;
      }

      final firstShot = frame.shots.first;

      int frameScore = 0;

      // Strike
      if (firstShot.numOfPinsKnocked == 10) {
        frameScore = 10 + _getNextTwoShots(frames, i);
      }
      // Spare
      else if (frame.shots.length >= 2 &&
          !firstShot.isFoul &&
          !frame.shots[1].isFoul &&
          frame.totalPinsDown == 10) {
        frameScore = 10 + _getNextOneShot(frames, i);
      }
      // Open or incomplete
      else {
        frameScore = frame.totalPinsDown;
      }

      cumulativeScore += frameScore;
      frameTotals.add(cumulativeScore);
    }

    // Frame 10
    if (frames.length > 9) {
      final frame10 = frames[9];
      if (frame10.shots.isNotEmpty) {
        cumulativeScore += frame10.totalPinsDown;
      }
      frameTotals.add(cumulativeScore);
    }

    return frameTotals;
  }

  /// Get frame outcome (X for strike, / for spare, - for gutter, or pin count)
  static String getFrameOutcome(Frame frame, int frameNumber) {
    if (frame.shots.isEmpty) return '-';

    final firstShot = frame.shots.first;

    // Strike
    if (firstShot.numOfPinsKnocked == 10) {
      return 'X';
    }

    // Gutter on first shot
    if (firstShot.numOfPinsKnocked == 0 && firstShot.isFoul) {
      return 'F'; // Foul
    }

    if (firstShot.numOfPinsKnocked == 0) {
      return '-'; // Gutter
    }

    // Need at least 2 shots to check for spare
    if (frame.shots.length < 2) {
      return firstShot.numOfPinsKnocked.toString();
    }

    final secondShot = frame.shots[1];

    // Spare
    if (frame.totalPinsDown == 10 && !firstShot.isFoul && !secondShot.isFoul) {
      return '/';
    }

    // Open frame
    return frame.totalPinsDown.toString();
  }
}
