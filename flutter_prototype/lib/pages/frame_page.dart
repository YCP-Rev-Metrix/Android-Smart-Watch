// pages/frame_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_page.dart'; // Assuming GameShell is in game_page.dart
import 'shot_page.dart';
import 'other_page.dart';
import '../controllers/session_controller.dart';

// Global access to the controller
final SessionController _sessionController = SessionController(); 


class FrameShell extends StatefulWidget {
  const FrameShell({super.key});

  @override
  State<FrameShell> createState() => _FrameShellState();
}

class _FrameShellState extends State<FrameShell> {
  // We should ideally track the current active frame based on the GameSession state
  // For now, keeping the UI frame index tracking for frame selection mode
  int _activeFrameIndex = 0; // 0-based index (0=Frame 1)
  bool _frameSelectMode = false;

  final List<Color> frameColors = [
    Colors.grey.shade900,
    Colors.grey.shade800,
    Colors.grey.shade700,
  ];

  void _enterFrameSelection() {
    HapticFeedback.selectionClick();
    setState(() => _frameSelectMode = true);
  }

  void _exitFrameSelection() {
    setState(() => _frameSelectMode = false);
  }

  void _selectFrame(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _activeFrameIndex = index;
      _frameSelectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // In a real app, this should look up the current active frame/game
    final currentShotNumber = (_sessionController.currentSession?.games
            .expand((g) => g.frames)
            .where((f) => f.shot != null)
            .length ?? 0) + 1;
            
    return WillPopScope(
      onWillPop: () async => _frameSelectMode,
      child: GestureDetector(
        onLongPress: _enterFrameSelection,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BowlingFrame(
              color: frameColors[_activeFrameIndex % frameColors.length], // Cycle colors
              frameIndex: _activeFrameIndex, // 0-based
              shotNumber: currentShotNumber,
            ),
            if (_frameSelectMode)
              FrameSelectionOverlay(
                activeFrame: _activeFrameIndex,
                colors: frameColors,
                onSelect: _selectFrame,
                onCancel: _exitFrameSelection,
              ),
          ],
        ),
      ),
    );
  }
}


// --- BowlingFrame ---

class BowlingFrame extends StatefulWidget {
  final Color color;
  final int frameIndex; // 0-based index
  final int shotNumber; // Global sequential shot number

  const BowlingFrame({
    super.key,
    required this.color,
    required this.frameIndex,
    required this.shotNumber,
  });

  @override
  State<BowlingFrame> createState() => _BowlingFrameState();
}

class _BowlingFrameState extends State<BowlingFrame> {
  final PageController _controller = PageController();
  // State 0 = Shot 1, State 1 = Shot 2 (based on PageView index)
  int _shotIndex = 0; // 0-based index for the PageView

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPageScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    final newIndex = _controller.page?.round() ?? _shotIndex;
    if (newIndex != _shotIndex) {
      setState(() => _shotIndex = newIndex);
    }
  }

  void _onVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
      // Swipe down to navigate to Game/Score page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: _onVerticalSwipe,
      behavior: HitTestBehavior.opaque,
      child: PageView(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        children: [
          // Shot 1 (Page 0)
          BowlingShot(
            key: ValueKey('${widget.frameIndex}-1'), // Key is crucial for state separation
            color: widget.color,
            frameIndex: widget.frameIndex,
            shotIndex: 1, // 1-based local shot
            globalShotNumber: widget.shotNumber,
          ),
          // Shot 2 (Page 1)
          BowlingShot(
            key: ValueKey('${widget.frameIndex}-2'),
            color: widget.color.withOpacity(0.85),
            frameIndex: widget.frameIndex,
            shotIndex: 2, // 1-based local shot
            globalShotNumber: widget.shotNumber,
          ),
        ],
      ),
    );
  }
}


// --- FrameSelectionOverlay (No changes needed) ---

class FrameSelectionOverlay extends StatefulWidget {
  final int activeFrame;
  final List<Color> colors;
  final ValueChanged<int> onSelect;
  final VoidCallback onCancel;

  const FrameSelectionOverlay({
    super.key,
    required this.activeFrame,
    required this.colors,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  State<FrameSelectionOverlay> createState() => _FrameSelectionOverlayState();
}

class _FrameSelectionOverlayState extends State<FrameSelectionOverlay> {
  late final PageController _controller;
  late int _selected;
  bool _isSettling = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.activeFrame;
    _controller = PageController(
      initialPage: _selected,
      viewportFraction: 0.8,
    );

    _controller.addListener(() {
      final page = _controller.page ?? _selected.toDouble();
      final diff = (page - page.round()).abs();
      final settling = diff > 0.001;
      if (settling != _isSettling) {
        setState(() => _isSettling = settling);
      }
    });
  }

  void _onPageChanged(int i) {
    setState(() => _selected = i);
    HapticFeedback.selectionClick();
  }

  void _onTapFrame(int i) {
    if (_isSettling) return;
    widget.onSelect(i);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.65; // slightly larger circles

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: GestureDetector(
          onTap: widget.onCancel,
          behavior: HitTestBehavior.opaque,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.colors.length,
            itemBuilder: (context, i) {
              final active = i == _selected;
              return Center(
                child: AnimatedScale(
                  scale: active ? 1.0 : 0.85,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    onTap: () => _onTapFrame(i),
                    child: Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        color: widget.colors[i],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Frame ${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}


// --- BowlingShot (Refactored for Model Integration) ---

class BowlingShot extends StatefulWidget {
  final int frameIndex; // 0-based
  final int shotIndex; // 1-based (1 or 2)
  final int globalShotNumber; // Sequential overall shot number
  final Color color;

  const BowlingShot({
    super.key,
    required this.frameIndex,
    required this.shotIndex,
    required this.globalShotNumber,
    required this.color,
  });

  @override
  State<BowlingShot> createState() => _BowlingShotState();
}

class _BowlingShotState extends State<BowlingShot> {
  // State variables for shot data (Non-final, mutable)
  List<bool> pinsStanding = List.filled(10, true); // true = standing (Initial state: all up)
  int lane = 1;
  int board = 18;
  double speed = 15.0;
  int ball = 1;
  String? position; // Stores 'X', '/', 'F' or count string

  // The state of the pins *before* this specific shot attempt.
  List<bool> _getInitialPins() {
    // Logic to determine initial pins for this specific shot in a frame.
    if (widget.shotIndex == 1) {
      return List.filled(10, true); // Always 10 pins for the first shot
    }
    
    // For Shot 2, we need the pins that were left standing after Shot 1.
    // This is complex and requires looking up the Shot 1 result from the Controller/GameSession.
    // Placeholder implementation: Assume all were down if Shot 1 hasn't been recorded.
    // *** IN A REAL APP: You must fetch the leaveType from the previous Shot. ***
    
    // TEMPORARY LOGIC: If we don't fetch the actual state, we use the last recorded state.
    // Since we're navigating away to ShotPage and coming back, we rely on the controller/state mgmt
    // to give us the previous frame's result or the pinsStanding from the state.
    
    // For now, to prevent the UI from being too complex, we'll initialize pinsStanding to 10
    // and rely on the navigation flow to update it correctly. 
    return pinsStanding;
  }
  
  void _recordShot(Map<String, dynamic> shotResult) async {
    // 1. Get Pin/Outcome data from ShotPage
    final List<bool> returnedPinsStanding = shotResult['pinsStanding'] as List<bool>;
    final int pinsDownCount = shotResult['pinsDownCount'] as int;
    final String? outcome = shotResult['outcome'] as String?;
    final bool isFoul = shotResult['isFoul'] as bool;

    // 2. Get Lane/Board/Speed data from OtherPage (if not already done)
    // We assume the user has either previously set these or uses the defaults.
    
    // 3. Update local state
    setState(() {
      pinsStanding = returnedPinsStanding;
      position = outcome;
    });

    // 4. Record the shot using the SessionController
    _sessionController.recordShot(
      // Data from OtherPage
      lane: lane,
      speed: speed,
      hitBoard: board,
      ball: ball, // Using default ball 1 for now
      
      // Data from ShotPage
      pinsStanding: returnedPinsStanding, // true = standing
      pinsDownCount: pinsDownCount,
      position: outcome ?? pinsDownCount.toString(), // Use count if no X, /, F
      isFoul: isFoul,
    );
    
    // 5. Check if the frame needs to advance page or frame
    // (Omitted: This logic would involve checking for Strike/Spare/Open/Foul and using the PageController to change to Shot 2 or the next Frame.)
  }

  void _showShotPages() async {
    // 1. Navigation to OtherPage (to confirm/set lane/board/speed)
    final updatedInfo = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => OtherPage(
          lane: lane,
          board: board,
          speed: speed,
          shotNumber: widget.globalShotNumber,
        ),
      ),
    );
    
    if (updatedInfo != null) {
      setState(() {
        lane = updatedInfo['lane'] as int;
        board = updatedInfo['board'] as int;
        speed = updatedInfo['speed'] as double;
      });
    }

    // 2. Navigation to ShotPage (to record pins/count/outcome)
    final shotResult = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ShotPage(
          initialPins: _getInitialPins(), // Pins standing before THIS shot
          shotNumber: widget.globalShotNumber,
        ),
      ),
    );

    if (shotResult != null) {
      _recordShot(shotResult);
    }
  }


@override
Widget build(BuildContext context) {
  // Use the local state variable 'lane' (which is non-final)
  final displayFrameNumber = widget.frameIndex + 1; // 1-based Frame number

  return Scaffold(
    backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
    extendBodyBehindAppBar: true,
    body: Center(
      child: GestureDetector(
        onTap: _showShotPages,
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            color: widget.color, // Use the frame's color
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Frame $displayFrameNumber — Shot ${widget.shotIndex}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Display the pins STANDING (pinsStanding = true for up)
              _buildPinDisplay(pinsStanding),
              const SizedBox(height: 6),

              // 👇 Info Bar (Data Section - Tap to edit)
              // The tap is now on the whole circle via the parent GestureDetector
              Transform.scale(
                scale: 0.8,
                child: _buildInfoBar(lane, board, speed, ball), // Pass local state variables
              ),
              
              // Simple display of last recorded outcome
              if (position != null) 
                Text(
                  'Last Shot: $position',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                )
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildPinDisplay(List<bool> pins) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [7, 8, 9, 10].map((p) => _buildPin(p, pins)).toList(),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [4, 5, 6].map((p) => _buildPin(p, pins)).toList(),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [2, 3].map((p) => _buildPin(p, pins)).toList(),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildPin(1, pins)],
        ),
      ],
    );
  }

  Widget _buildPin(int pinNumber, List<bool> pins) {
    final index = pinNumber - 1;
    // pins[index] is true if STANDING (UP)
    final isStanding = pins[index]; 
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        // Color logic updated: STANDING uses the purple color (like in shot_page)
        color: isStanding ? const Color.fromRGBO(142, 124, 195, 1) : const Color.fromRGBO(153, 153, 153, 1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 0.5),
      ),
    );
  }

  // Adjusted _buildInfoBar to match signature and removed unused height param
  Widget _buildInfoBar(int lane, int board, double speed, int ball) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(153, 153, 153, 1),
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildInfoCell('Lane', lane.toString()),
          _buildDivider(),
          _buildInfoCell('Board', board.toString()),
          _buildDivider(),
          _buildInfoCell('Speed', speed.toStringAsFixed(1)),
          _buildDivider(),
          _buildInfoCell('Ball', ball.toString()),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.black.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(horizontal: 3),
    );
  }


  Widget _buildInfoCell(String label, String value) {
    return Container(
      width: 36,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black, fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.black, fontSize: 14),
          ),
        ],
      ),
    );
  }
}