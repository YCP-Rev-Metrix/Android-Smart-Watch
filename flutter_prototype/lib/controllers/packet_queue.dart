// controllers/packet_queue.dart
import 'dart:async';
import 'dart:collection';
import '../models/shot.dart';

/// A singleton FCFS (First-Come, First-Served) queue for [Shot] packets.
///
/// The 10-second processing loop starts automatically when the first shot is
/// enqueued and stops on its own once the queue becomes empty.
class PacketQueue {
  PacketQueue._internal();

  static final PacketQueue instance = PacketQueue._internal();

  /// Internal FCFS queue – [Queue] preserves insertion order and supports
  /// O(1) access to both ends.
  final Queue<Shot> _queue = Queue<Shot>();

  Timer? _processingTimer;

  /// Starts the internal processing loop (called automatically by [enqueue]).
  void _startProcessing() {
    if (_processingTimer != null) return; // already running
    _processingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_queue.isNotEmpty) {
        // ignore: avoid_print
        print('[PacketQueue] Next shot in queue: ${_queue.first.toJson()}\n'
            '[PacketQueue] Queue length: ${_queue.length}');
      } else {
        // Queue drained – stop the timer until another shot arrives.
        _processingTimer?.cancel();
        _processingTimer = null;
        // ignore: avoid_print
        print('[PacketQueue] Queue empty, processing loop stopped.');
      }
    });
  }

  /// Adds a [Shot] to the back of the queue (FCFS enqueue).
  /// Automatically starts the processing loop if it isn't already running.
  void enqueue(Shot shot) {
    _queue.addLast(shot);
    // ignore: avoid_print
    print('[PacketQueue] Enqueued shot #${shot.shotNumber}. '
        'Queue length: ${_queue.length}');
    _startProcessing();
  }

  /// Removes and returns the [Shot] at the front of the queue, or null if empty.
  Shot? dequeue() {
    if (_queue.isEmpty) return null;
    return _queue.removeFirst();
  }

  /// Returns the [Shot] at the front without removing it, or null if empty.
  Shot? peek() => _queue.isNotEmpty ? _queue.first : null;

  /// Current number of shots waiting in the queue.
  int get length => _queue.length;

  /// Whether the queue has no pending shots.
  bool get isEmpty => _queue.isEmpty;
}
