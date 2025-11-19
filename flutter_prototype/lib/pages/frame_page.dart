// lib/pages/frame_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_page.dart'; 
import 'shot_page.dart'; 
import 'other_page.dart'; 
import '../controllers/session_controller.dart'; 
import '../models/frame.dart'; 

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
  // State to track which frame the user is currently viewing.
  late int _viewFrameIndex;
  
  bool _frameSelectMode = false;

  // Define a small, fixed list of repeating colors
  final List<Color> frameColorPalette = const [
    Color.fromRGBO(67, 67, 67, 1),
    Color.fromRGBO(67, 67, 67, 1),
    Color.fromRGBO(67, 67, 67, 1),
  ];
  
  // Dynamic getter for the current frame index the user MUST input data into.
  int get _currentActiveFrameIndex => _sessionController.activeFrameIndex;

  @override
  void initState() {
    super.initState();
    // 1. Initialize view to the active input frame.
    _viewFrameIndex = _currentActiveFrameIndex;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When dependencies change, ensure the view is snapped to the active frame 
    // only if the user hasn't explicitly selected a past frame via the overlay.
    if (_viewFrameIndex == _currentActiveFrameIndex) {
        _viewFrameIndex = _currentActiveFrameIndex;
    }
  }

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
    // 2. When exiting selection mode, explicitly reset the view back to the active input frame.
    setState(() {
      _viewFrameIndex = _currentActiveFrameIndex;
      _frameSelectMode = false;
    });
  }

  void _selectFrame(int index) {
    HapticFeedback.lightImpact();
    // 3. User selection sets the view index and exits selection mode.
    setState(() {
      _viewFrameIndex = index; 
      _frameSelectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sessionController,
      builder: (context, child) {
        // Recalculate the active input index (0-based)
        final inputFrameIndex = _currentActiveFrameIndex; 
        
        // --- CRITICAL FIX: Boundary Check ---
        final gameFrames = _sessionController.currentSession!.games.first.frames;
        final maxValidIndex = gameFrames.length - 1;

        // Ensure _viewFrameIndex is within bounds (0 to maxValidIndex)
        if (_viewFrameIndex < 0 || _viewFrameIndex > maxValidIndex) {
          // If it's out of bounds, reset it to the currently active input frame.
          _viewFrameIndex = inputFrameIndex.clamp(0, maxValidIndex).toInt();
        }
        // --- End Boundary Check ---

        // Calculate the total number of shots taken up to the start of the view frame.
        final shotsBeforeViewFrame = gameFrames
            .take(_viewFrameIndex)
            .fold(0, (sum, f) => sum + f.shots.length);
        
        // The global shot number of the *next* potential shot in the view frame
        final currentGlobalShotNumber = shotsBeforeViewFrame + (gameFrames[_viewFrameIndex].shots.length) + 1;
        
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
                  frameIndex: _viewFrameIndex, 
                  // Use modulo operator to assign the color dynamically
                  color: frameColorPalette[_viewFrameIndex % frameColorPalette.length], 
                  shotNumber: currentGlobalShotNumber, 
                  isInputActive: _viewFrameIndex == inputFrameIndex,
                ),
                if (_frameSelectMode)
                  FrameSelectionOverlay(
                    maxSelectableFrame: inputFrameIndex, 
                    activeFrame: _viewFrameIndex, 
                    colors: frameColorPalette, 
                    onSelect: _selectFrame,
                    onCancel: _exitFrameSelection,
                  ),
              ],
            ),
          ),
        );
      }
    );
  }
}

// #############################################################
//                         2. BOWLING FRAME 
// #############################################################

class BowlingFrame extends StatefulWidget {
  final Color color;
  final int frameIndex; 
  final int shotNumber; 
  final bool isInputActive; // Flag if this frame is where input should happen

  const BowlingFrame({
    super.key,
    required this.color,
    required this.frameIndex,
    required this.shotNumber,
    required this.isInputActive, 
  });

  @override
  State<BowlingFrame> createState() => _BowlingFrameState();
}

class _BowlingFrameState extends State<BowlingFrame> {
  late PageController _controller; 
  
  // Determine the shot index (0 or 1) that needs input
  int _getActiveShotIndex(Frame frame) {
    return frame.shots.length; // 0 for shot 1, 1 for shot 2, etc.
  }
  
  @override
  void initState() {
    super.initState();
    _initializeController();
  }
  
  void _initializeController() {
    final activeGame = _sessionController.currentSession!.games.first;
    final frame = activeGame.frames[widget.frameIndex];
    // This correctly determines the page for the shot being viewed/inputted.
    final initialPage = _getActiveShotIndex(frame); 
    
    _controller = PageController(initialPage: initialPage);
    _controller.addListener(_onPageScroll);
  }

  @override
  void didUpdateWidget(covariant BowlingFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frameIndex != widget.frameIndex) {
      // Dispose of the old controller
      _controller.dispose();
      
      // Initialize the new controller, setting the correct initialPage
      _initializeController();
      
      // The Pages are now dynamically sized, so no post-frame jump is necessary.
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPageScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    // No specific action needed here
  }

  @override
  Widget build(BuildContext context) {
    final activeGame = _sessionController.currentSession!.games.first;
    final frame = activeGame.frames[widget.frameIndex];
    
    // Declare pageCount as a mutable 'int' variable.
    int pageCount; 
    
    if (frame.isComplete || !widget.isInputActive) {
        // If the frame is done, or if we are viewing a past frame, 
        // show only the recorded shots (enables editing previous completed shots).
        pageCount = frame.shots.length;
    } else {
        // If it's the active frame for input, show recorded shots + 1 empty shot screen.
        pageCount = frame.shots.length + 1;
    }
    
    // Safety check for the 10th frame (Index 9), ensuring we don't exceed 3 pages.
    if (widget.frameIndex == 9 && pageCount > 3) {
      pageCount = 3; 
    }
    
    // If the frame hasn't been started (0 shots), ensure there's 1 page if input is active.
    if (pageCount == 0 && widget.isInputActive) {
      pageCount = 1;
    } else if (pageCount == 0 && !widget.isInputActive) {
      // If we are viewing a past frame that was never started, show 1 page.
      pageCount = 1; 
    }


    // Allow scrolling on all pages to enable reviewing/editing past shots.
    final scrollPhysics = widget.isInputActive && !frame.isComplete
      ? const NeverScrollableScrollPhysics() 
      : const BouncingScrollPhysics();

    return PageView.builder(
      controller: _controller,
      physics: scrollPhysics,
      itemCount: pageCount, // Use the dynamic count here
      itemBuilder: (context, shotIndex) {
        
        // Calculate the starting global shot number for this PageView
        final shotsBeforeFrame = activeGame.frames
            .take(widget.frameIndex)
            .fold(0, (sum, f) => sum + f.shots.length);
        final initialGlobalShot = shotsBeforeFrame + 1;
        
        // Determine if this is the input page (index matches number of recorded shots)
        final bool isInputPage = shotIndex == frame.shots.length;
        
        return BowlingShot(
          key: ValueKey('${widget.frameIndex}-${shotIndex + 1}'), 
          color: widget.color, 
          frameIndex: widget.frameIndex,
          shotIndex: shotIndex + 1,
          globalShotNumber: initialGlobalShot + shotIndex, 
          // isInputActive is only true if we are on the current active frame AND the input page
          // This flag controls the visual appearance and whether recording/saving occurs.
          isInputActive: widget.isInputActive && isInputPage,
          // Flag if ANY editing should be allowed (true for all recorded shots + the current input page).
          isEditable: widget.isInputActive || shotIndex < frame.shots.length,
        );
      },
    );
  }
}

// #############################################################
//                         3. FRAME SELECTION OVERLAY 
// #############################################################

class FrameSelectionOverlay extends StatefulWidget {
  final int activeFrame; // The frame currently selected/viewed
  final int maxSelectableFrame; // The index of the furthest frame (current input frame)
  final List<Color> colors;
  final ValueChanged<int> onSelect;
  final VoidCallback onCancel;

  const FrameSelectionOverlay({
    super.key,
    required this.activeFrame,
    required this.maxSelectableFrame, 
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
            // CRITICAL: Restrict the number of pages displayed (up to the current active frame)
            itemCount: widget.maxSelectableFrame + 1, 
            itemBuilder: (context, i) {
              final active = i == _selected;
              
              final isComplete = _sessionController.currentSession!.games.first.frames[i].isComplete;
              
              // FIX: Use modulo operator to cycle through colors dynamically
              final int colorIndex = i % widget.colors.length;
              
              final Color frameColor = isComplete 
                ? widget.colors[colorIndex] 
                : widget.colors[colorIndex].withOpacity(0.5);
              
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
                        color: frameColor, 
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
//                         4. BOWLING SHOT (Data Display)
// #############################################################

class BowlingShot extends StatefulWidget {
  final int frameIndex; // 0-based
  final int shotIndex; // 1-based (1 or 2)
  final int globalShotNumber;
  final Color color; 
  final bool isInputActive; // Flag if this specific shot is ready for input
  final bool isEditable; // Flag if this shot can be tapped to edit (true for all recorded shots)

  const BowlingShot({
    super.key,
    required this.frameIndex,
    required this.shotIndex,
    required this.globalShotNumber,
    required this.color,
    required this.isInputActive, 
    required this.isEditable, 
  });

  @override
  State<BowlingShot> createState() => _BowlingShotState();
}

class _BowlingShotState extends State<BowlingShot> {
  
  int lane = 1;
  int board = 18;
  double speed = 15.0;
  int ball = 1;
  String? position;
  List<bool> pinsDown = List.filled(10, false); 
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateShotDisplay();
  }
  
  @override
  void didUpdateWidget(covariant BowlingShot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Important: Re-read the data if the frame/shot context changes
    if (oldWidget.frameIndex != widget.frameIndex || oldWidget.shotIndex != widget.shotIndex) {
      _updateShotDisplay();
    }
  }

  // Reads the current/previous shot data from the controller models
  void _updateShotDisplay() {
    final activeGame = _sessionController.currentSession!.games.first;
    final frame = activeGame.frames[widget.frameIndex];
    
    // Determine which shot data to display (if any)
    final shotToDisplay = frame.shots.length >= widget.shotIndex
        ? frame.shots[widget.shotIndex - 1] // Use the recorded shot
        : null; // Use current defaults/placeholders
        
    setState(() {
      if (shotToDisplay != null) {
        // Use shot data
        // PinsDown is true for pins that are DOWN (opposite of the model's 'pinsState')
        pinsDown = shotToDisplay.pinsState.map((isStanding) => !isStanding).toList();
        lane = frame.lane;
        board = shotToDisplay.hitBoard;
        speed = shotToDisplay.speed;
        ball = shotToDisplay.ball;
        position = shotToDisplay.position;
      } else {
        // Use default/placeholder data for the upcoming shot
        pinsDown = List.filled(10, false); 
        lane = 1;
        board = 18;
        speed = 15.0;
        ball = 1;
        position = null;
      }
    });
  }


  void _openOtherPage() async {
    // Allow opening for ALL shots where 'isEditable' is true (which includes past shots).
    if (!widget.isEditable) return; 
    
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
      
      // If a shot was edited, and it was a *recorded* shot (not the current input page), 
      // we need to call editShot to update the metadata in the model.
      if (!widget.isInputActive) {
        _editShot(isMetadataOnly: true);
      }
    }
  }

  void _openShotPage() async {
    // Allow opening for ALL shots where 'isEditable' is true.
    if (!widget.isEditable) return;

    final activeGame = _sessionController.currentSession!.games.first;

    // Determine the pins standing before this specific shot was taken.
    final List<bool> initialPinsStanding;
    if (widget.shotIndex == 1) {
        // Shot 1 always starts with all pins standing
        initialPinsStanding = List.filled(10, true); 
    } else {
        // For shot 2/3, find the pins left from the *previous* shot in the frame.
        final previousShotIndex = widget.shotIndex - 2;
        if (activeGame.frames[widget.frameIndex].shots.length > previousShotIndex && previousShotIndex >= 0) {
            initialPinsStanding = activeGame.frames[widget.frameIndex].shots[previousShotIndex].pinsState;
        } else {
            // Fallback
            initialPinsStanding = List.filled(10, true);
        }
    }


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
        // If we are editing a past shot, we need a special controller method.
        if (widget.isInputActive) {
            _recordShot(shotResult);
        } else {
            // Logic to re-record/edit a past shot (pins/count change).
            _editShot(shotResult: shotResult);
        }
    }
  }
  
  void _recordShot(Map<String, dynamic> shotResult) {
    // 🎯 FIX: Changed key from 'pinsStanding' to 'standingPins'
    final List<bool> standingPinsResult = shotResult['pinsStanding'] as List<bool>; 
    final int pinsDownCount = shotResult['pinsDownCount'] as int;
    final String? outcome = shotResult['outcome'] as String?;
    final bool isFoul = shotResult['isFoul'] as bool;
    
    _sessionController.recordShot(
      lane: lane,
      speed: speed,
      hitBoard: board,
      ball: ball, 
      // 🎯 FIX: Changed parameter name to standingPins
      standingPins: standingPinsResult, 
      pinsDownCount: pinsDownCount,
      position: outcome ?? pinsDownCount.toString(),
      isFoul: isFoul,
    );
  }
  
  // Method to edit a recorded shot, used for both pin data and metadata changes.
  void _editShot({Map<String, dynamic>? shotResult, bool isMetadataOnly = false}) {
    
    // 🎯 FIX: Changed key from 'pinsStanding' to 'standingPins'
    final List<bool> standingPinsResult = isMetadataOnly 
        ? pinsDown.map((isDown) => !isDown).toList() // Use current pinsDown state (converted to standing)
        : shotResult!['pinsStanding'] as List<bool>; 
        
    final int pinsDownCount = isMetadataOnly
        ? _sessionController.currentSession!.games.first.frames[widget.frameIndex].shots[widget.shotIndex - 1].count
        : shotResult!['pinsDownCount'] as int;
        
    final String? outcome = isMetadataOnly
        ? position // Keep current position
        : shotResult!['outcome'] as String?;
        
    final bool isFoul = isMetadataOnly
        ? _sessionController.currentSession!.games.first.frames[widget.frameIndex].shots[widget.shotIndex - 1].isFoul
        : shotResult!['isFoul'] as bool;

    // This is the index of the shot *within the current frame* (0-based)
    final shotIndexInFrame = widget.shotIndex - 1; 

    _sessionController.editShot(
      frameIndex: widget.frameIndex,
      shotIndexInFrame: shotIndexInFrame,
      lane: lane,
      speed: speed,
      hitBoard: board,
      ball: ball, 
      // 🎯 FIX: Changed parameter name to standingPins
      standingPins: standingPinsResult, 
      pinsDownCount: pinsDownCount,
      position: outcome ?? pinsDownCount.toString(),
      isFoul: isFoul,
    );
    
    // After editing, the display state must be updated locally.
    _updateShotDisplay();
  }

  Widget _buildPinDisplay(List<bool> pinsDownList) {
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
      backgroundColor: widget.color,
      extendBodyBehindAppBar: true,
      body: Center(
        child: GestureDetector(
          // Tapping opens shot page if it's editable.
          onTap: widget.isEditable ? _openShotPage : null, 
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: widget.color,
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
                  // Tapping info bar opens OtherPage if it's editable.
                  onTap: widget.isEditable ? _openOtherPage : null, 
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