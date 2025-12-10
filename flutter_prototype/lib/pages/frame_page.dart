// lib/pages/frame_page.dart


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_page.dart';
import 'shot_page.dart';
// 'OtherPage' route removed — no external page for editing lane/board/speed anymore
import '../controllers/session_controller.dart';
import '../models/frame.dart';
import '../models/shot.dart';


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
    
     // 🎯 FIX: Removed WidgetsBinding.instance.addPostFrameCallback logic.
     // The new controller is initialized with the correct page and will handle it.
   }
    // If this frame becomes the active input frame (or remains active after a shot was recorded), ensure the PageView shows the active shot page.
    // This handles the case where a shot was recorded and the active shot index advanced; jump the controller to the new active page.
    if (widget.isInputActive) {
      final activeGame = _sessionController.currentSession!.games.first;
      final frame = activeGame.frames[widget.frameIndex];
      final int activeShotIndex = frame.shots.length; // 0 for first shot, 1 for second, etc.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          try {
            _controller.jumpToPage(activeShotIndex);
          } catch (_) {
            // ignore if jump fails during rebuild
          }
        }
      });
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
   final activeShotIndex = _getActiveShotIndex(frame); // 0 or 1


   // Only restrict scrolling if it's the active input frame AND incomplete.
   final scrollPhysics = widget.isInputActive && !frame.isComplete
     ? const NeverScrollableScrollPhysics()
     : const BouncingScrollPhysics();


   return PageView.builder(
     controller: _controller,
     physics: scrollPhysics,
     itemCount: 3, // Allow 3 pages (for the 10th frame)
     itemBuilder: (context, shotIndex) {
      
       // Calculate the starting global shot number for this PageView
       final shotsBeforeFrame = activeGame.frames
           .take(widget.frameIndex)
           .fold(0, (sum, f) => sum + f.shots.length);
       final initialGlobalShot = shotsBeforeFrame + 1;
      
       // Logic to determine visibility:
       final bool isVisible;
       if (widget.isInputActive) {
           // If active input, show the shot being input (activeShotIndex)
           isVisible = shotIndex == activeShotIndex;
       } else {
           // If viewing past frame, only show shots that have been recorded
           isVisible = shotIndex < frame.shots.length;
       }
      
       if (!isVisible) {
         return Container(color: widget.color);
       }
      
       return BowlingShot(
         key: ValueKey('${widget.frameIndex}-${shotIndex + 1}'),
         color: widget.color,
         frameIndex: widget.frameIndex,
         shotIndex: shotIndex + 1,
         globalShotNumber: initialGlobalShot + shotIndex,
         // Pass the input status down to BowlingShot
         isInputActive: widget.isInputActive && (shotIndex == activeShotIndex),
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


 const BowlingShot({
   super.key,
   required this.frameIndex,
   required this.shotIndex,
   required this.globalShotNumber,
   required this.color,
   required this.isInputActive,
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
       pinsDown = shotToDisplay.pinsState.map((isStanding) => !isStanding).toList();
       lane = frame.lane;
       board = shotToDisplay.hitBoard;
       speed = shotToDisplay.speed;
       ball = shotToDisplay.ball;
       position = shotToDisplay.position;
     } else {
      // For an upcoming shot, prefer to pre-fill values from the last
      // recorded shot in this frame when available. If no prior shot
      // exists, fall back to the user's global defaults stored in the
      // SessionController so dropdown choices persist across shots/frames.
      pinsDown = List.filled(10, false);
      if (frame.shots.isNotEmpty) {
        final lastShot = frame.shots.last;
        lane = frame.lane; // frame.lane is updated when recording shots
        board = lastShot.hitBoard;
        speed = lastShot.speed;
        ball = lastShot.ball;
        position = null;
      } else {
        // Use controller-level defaults when this frame has no prior shots
        lane = _sessionController.defaultLane;
        board = _sessionController.defaultBoard;
        speed = _sessionController.defaultSpeed;
        ball = _sessionController.defaultBall;
        position = null;
      }
     }
   });
 }




 // _openOtherPage removed — OtherPage editor route is disabled.


 void _openShotPage() async {
   // Only allow recording if this is the currently active shot
   if (!widget.isInputActive) return;


   final activeGame = _sessionController.currentSession!.games.first;


   // Logic to set initial pins based on whether it's shot 1 or a subsequent shot
   final initialPinsStanding = widget.shotIndex == 1
       ? List.filled(10, true) // Reset for Shot 1
       // For shot 2/3, use the pins left from the previous shot in the frame
       : activeGame.frames[widget.frameIndex].shots.last.pinsState;


   final shotResult = await Navigator.push<Map<String, dynamic>>(
     context,
     MaterialPageRoute(
       builder: (_) => ShotPage(
         initialPins: initialPinsStanding,
         shotNumber: widget.globalShotNumber,
         // Pass current local selections so ShotPage dropdowns/picker are
         // initialized to the user's last-used values for consistency.
        frameShotIndex: widget.shotIndex,
        initialLane: lane,
         initialBoard: board,
         initialBall: ball,
         initialSpeed: speed,
       ),
     ),
   );


   if (shotResult != null) {
     // Update the info bar values with selections returned from the shot page
     setState(() {
       lane = (shotResult['lane'] as int?) ?? lane;
       board = (shotResult['board'] as int?) ?? board;
       speed = (shotResult['speed'] as double?) ?? speed;
       ball = (shotResult['ball'] as int?) ?? ball;
     });
     _recordShot(shotResult);
   }
 }
 void _recordShot(Map<String, dynamic> shotResult) {
   final List<bool> pinsStandingResult = shotResult['pinsStanding'] as List<bool>;
   final int pinsDownCount = shotResult['pinsDownCount'] as int;
   final String? outcome = shotResult['outcome'] as String?;
   final bool isFoul = shotResult['isFoul'] as bool;
  
   _sessionController.recordShot(
     lane: lane,
     speed: speed,
     hitBoard: board,
     ball: ball,
     standingPins: pinsStandingResult,
     pinsDownCount: pinsDownCount,
     position: outcome ?? pinsDownCount.toString(),
     isFoul: isFoul,
   );
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
         // Tapping only opens the shot page if it's the active input shot
         onTap: widget.isInputActive ? _openShotPage : null,
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
                 // Info bar is read-only now; tapping does nothing
                 onTap: null,
                 child: Transform.scale(
                   scale: 0.8,
                   child: _buildInfoBar(lane, board, speed, ball),
                 ),
               ),
              
               // Removed 'Last Shot' label per UX request.
             ],
           ),
         ),
       ),
     ),
   );
 }
}
