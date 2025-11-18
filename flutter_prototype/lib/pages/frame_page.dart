// lib/pages/frame_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_page.dart'; // To navigate to GameShell
import 'shot_page.dart'; // To navigate to the pin selection page
import 'other_page.dart'; // To navigate to the lane/board/speed settings page
import '../controllers/session_controller.dart'; 

// Global access to the controller
final SessionController _sessionController = SessionController(); 


// #############################################################
//                         1. FRAME SHELL 
// #############################################################

class FrameShell extends StatefulWidget {
  const FrameShell({super.key});

  @override
  State<FrameShell> createState() => _FrameShellState();
}

class _FrameShellState extends State<FrameShell> {
  int _activeFrameIndex = 0; // 0-based index (0=Frame 1)
  bool _frameSelectMode = false;

  final List<Color> frameColors = [
    Colors.grey.shade900,
    Colors.grey.shade800,
    Colors.grey.shade700,
  ];
  
  // 🎯 FIX: Swipe logic needs to be here, attached to the main screen GestureDetector
  void _onVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    // Swipe down (positive velocity) → go back to GameShell (Scoreboard)
    if (details.primaryVelocity! > 200) {
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        // Using MaterialPageRoute for navigation logic (you might use pop if pushing from GameShell was replaced)
        MaterialPageRoute(builder: (_) => const GameShell()),
      );
    }
  }

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
    final currentShotNumber = (_sessionController.currentSession?.games
            .expand((g) => g.frames)
            .where((f) => f.shot != null)
            .length ?? 0) + 1;
            
    return WillPopScope(
      onWillPop: () async => _frameSelectMode,
      // 🎯 CRITICAL: GestureDetector is attached here for the whole screen
      child: GestureDetector(
        onLongPress: _enterFrameSelection,
        // 🎯 CRITICAL: Attach the swipe handler here
        onVerticalDragEnd: _onVerticalSwipe, 
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // BowlingFrame contains the actual UI (PageView)
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

// #############################################################
//                         2. BOWLING FRAME 
// #############################################################

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
  int _shotIndex = 0; // 0-based index for the PageView
  
  // State variables for shot data (must be present for _recordShot and UI display)
  List<bool> pinsStanding = List.filled(10, true);
  int lane = 1;
  int board = 18;
  double speed = 15.0;
  int ball = 1;
  String? position;

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

  // NOTE: Swipe logic is removed from here and placed in FrameShell to cover the entire screen.
  
  // Required methods for BowlingShot functionality
  List<bool> _getInitialPins() {
    // Logic for Shot 1: Always 10 pins (true)
    if (_shotIndex == 0) { // Shot index 0 is first shot
      return List.filled(10, true);
    }
    // For Shot 2: Pins left standing after Shot 1
    return pinsStanding;
  }

  void _recordShot(Map<String, dynamic> shotResult) async {
    final List<bool> returnedPinsStanding = shotResult['pinsStanding'] as List<bool>;
    final int pinsDownCount = shotResult['pinsDownCount'] as int;
    final String? outcome = shotResult['outcome'] as String?;
    final bool isFoul = shotResult['isFoul'] as bool;

    setState(() {
      pinsStanding = returnedPinsStanding;
      position = outcome;
    });

    _sessionController.recordShot(
      lane: lane,
      speed: speed,
      hitBoard: board,
      ball: ball, 
      pinsStanding: returnedPinsStanding,
      pinsDownCount: pinsDownCount,
      position: outcome ?? pinsDownCount.toString(),
      isFoul: isFoul,
    );
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
          shotNumber: widget.shotNumber, // Passing global shot number
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
          initialPins: _getInitialPins(),
          shotNumber: widget.shotNumber, // Passing global shot number
        ),
      ),
    );

    if (shotResult != null) {
      _recordShot(shotResult);
    }
  }
  
  // Utility methods for the UI (restored from previous versions)
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
    final isStanding = pins.length > index ? pins[index] : true; // Safety check
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isStanding ? const Color.fromRGBO(142, 124, 195, 1) : const Color.fromRGBO(153, 153, 153, 1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 0.5),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    // NOTE: GestureDetector is NOT here, it is in FrameShell now.
    return PageView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      children: [
        // Shot 1 (Page 0)
        BowlingShot(
          key: ValueKey('${widget.frameIndex}-1'), 
          color: widget.color,
          frameIndex: widget.frameIndex,
          shotIndex: 1, // 1-based local shot
          globalShotNumber: widget.shotNumber,
          showPages: _showShotPages,
          lane: lane, board: board, speed: speed, 
          position: position, pinsStanding: _getInitialPins(), // Use initial pins for display
          buildPinDisplay: _buildPinDisplay,
          buildInfoBar: _buildInfoBar,
        ),
        // Shot 2 (Page 1)
        BowlingShot(
          key: ValueKey('${widget.frameIndex}-2'),
          color: widget.color.withOpacity(0.85),
          frameIndex: widget.frameIndex,
          shotIndex: 2, // 1-based local shot
          globalShotNumber: widget.shotNumber,
          showPages: _showShotPages,
          lane: lane, board: board, speed: speed, 
          position: position, pinsStanding: _getInitialPins(), // Use pins left from Shot 1
          buildPinDisplay: _buildPinDisplay,
          buildInfoBar: _buildInfoBar,
        ),
      ],
    );
  }
}

// #############################################################
//                         3. FRAME SELECTION OVERLAY
// #############################################################

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
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final circleSize = size.width * 0.65; 

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

// #############################################################
//                         4. BOWLING SHOT (Data Input UI)
// #############################################################

class BowlingShot extends StatelessWidget {
  final int frameIndex;
  final int shotIndex;
  final int globalShotNumber;
  final Color color;
  final VoidCallback showPages; 
  final int lane;
  final int board;
  final double speed;
  final String? position;
  final List<bool> pinsStanding;
  final int ball = 1;

  // Function types passed from the parent state to build UI components
  final Widget Function(List<bool>) buildPinDisplay;
  final Widget Function(int, int, double, int) buildInfoBar;

  const BowlingShot({
    super.key,
    required this.frameIndex,
    required this.shotIndex,
    required this.globalShotNumber,
    required this.color,
    required this.showPages,
    required this.lane,
    required this.board,
    required this.speed,
    required this.position,
    required this.pinsStanding,
    required this.buildPinDisplay,
    required this.buildInfoBar,
  });

  @override
  Widget build(BuildContext context) {
    final displayFrameNumber = frameIndex + 1;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
      extendBodyBehindAppBar: true,
      body: Center(
        child: GestureDetector(
          onTap: showPages,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: color, 
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Frame $displayFrameNumber — Shot $shotIndex',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Display the pins STANDING using the passed function
                buildPinDisplay(pinsStanding),
                const SizedBox(height: 6),

                // Info Bar (Data Section - Tap to edit)
                Transform.scale(
                  scale: 0.8,
                  child: buildInfoBar(lane, board, speed, ball), 
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
}