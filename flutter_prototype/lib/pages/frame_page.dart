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

  // 🎯 MODIFIED: All frameColors are now the same dark grey for a unified background
  final List<Color> frameColors = const [
    Color.fromRGBO(67, 67, 67, 1),
    Color.fromRGBO(67, 67, 67, 1),
    Color.fromRGBO(67, 67, 67, 1),
  ];
  
  void _onVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    if (details.primaryVelocity! > 200) {
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
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
      child: GestureDetector(
        onLongPress: _enterFrameSelection,
        onVerticalDragEnd: _onVerticalSwipe, 
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BowlingFrame(
              color: frameColors[_activeFrameIndex % frameColors.length], 
              frameIndex: _activeFrameIndex, 
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
    // No specific action needed here for background color change
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      children: [
        // Shot 1 (Page 0)
        BowlingShot(
          key: ValueKey('${widget.frameIndex}-1'), 
          color: widget.color, // This will now be the unified dark grey
          frameIndex: widget.frameIndex,
          shotIndex: 1, 
          globalShotNumber: widget.shotNumber,
        ),
        // Shot 2 (Page 1)
        BowlingShot(
          key: ValueKey('${widget.frameIndex}-2'),
          color: widget.color, // 🎯 MODIFIED: Removed .withOpacity to match
          frameIndex: widget.frameIndex,
          shotIndex: 2, 
          globalShotNumber: widget.shotNumber,
        ),
      ],
    );
  }
}

// #############################################################
//                         3. FRAME SELECTION OVERLAY (Unchanged for logic, but colors will reflect change)
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
                        color: widget.colors[i], // This will now be the unified dark grey
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
//                         4. BOWLING SHOT (Unified Background)
// #############################################################

class BowlingShot extends StatefulWidget {
  final int frameIndex; // 0-based
  final int shotIndex; // 1-based (1 or 2)
  final int globalShotNumber;
  final Color color; // This will now always be the unified dark grey

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
  List<bool> pinsDown = List.filled(10, false); 
  int lane = 1;
  int board = 18;
  double speed = 15.0;
  int ball = 1;
  String? position;
  
  List<bool> _getPinsStandingForDisplay() {
    return pinsDown.map((isDown) => !isDown).toList(); 
  }

  void _openOtherPage() async {
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
  }

  void _openShotPage() async {
    final initialPinsStanding = _getPinsStandingForDisplay();

    final shotResult = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ShotPage(
          initialPins: initialPinsStanding, 
          shotNumber: widget.globalShotNumber,
        ),
      ),
    );

    if (shotResult != null) {
      _recordShot(shotResult);
    }
  }
  
  void _recordShot(Map<String, dynamic> shotResult) {
    final List<bool> pinsStandingResult = shotResult['pinsStanding'] as List<bool>; 
    final int pinsDownCount = shotResult['pinsDownCount'] as int;
    final String? outcome = shotResult['outcome'] as String?;
    final bool isFoul = shotResult['isFoul'] as bool;
    
    final newPinsDown = pinsStandingResult.map((isStanding) => !isStanding).toList(); 

    setState(() {
      pinsDown = newPinsDown; 
      position = outcome;
    });

    _sessionController.recordShot(
      lane: lane,
      speed: speed,
      hitBoard: board,
      ball: ball, 
      pinsStanding: pinsStandingResult, 
      pinsDownCount: pinsDownCount,
      position: outcome ?? pinsDownCount.toString(),
      isFoul: isFoul,
    );
  }

  Widget _buildPinDisplay(List<bool> pinsDownList) { // pinsDownList here corresponds to the state `pinsDown`
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [7, 8, 9, 10].map((p) => _buildPin(p, pinsDownList)).toList(),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [4, 5, 6].map((p) => _buildPin(p, pinsDownList)).toList(),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [2, 3].map((p) => _buildPin(p, pinsDownList)).toList(),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildPin(1, pinsDownList)],
        ),
      ],
    );
  }

  Widget _buildPin(int pinNumber, List<bool> pinsDownList) {
    final index = pinNumber - 1;
    final isDown = pinsDownList[index]; 
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isDown ? const Color.fromRGBO(153, 153, 153, 1) : const Color.fromRGBO(142, 124, 195, 1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 0.5),
      ),
    );
  }

  Widget _buildInfoBar(int lane, int board, double speed, int ball) {
    const double height = 50; 
    return Container(
      height: height,
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
          _buildInfoCell('Ball', '1'), 
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
    final displayFrameNumber = widget.frameIndex + 1;

    return Scaffold(
      backgroundColor: widget.color, // 🎯 MODIFIED: Use widget.color for Scaffold background too
      extendBodyBehindAppBar: true,
      body: Center(
        child: GestureDetector(
          onTap: _openShotPage, 
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: widget.color, // This will now also be the unified dark grey
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
                _buildPinDisplay(pinsDown),
                const SizedBox(height: 6),

                GestureDetector(
                  onTap: _openOtherPage, 
                  child: Transform.scale(
                    scale: 0.8,
                    child: _buildInfoBar(lane, board, speed, ball), 
                  ),
                ),
                
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