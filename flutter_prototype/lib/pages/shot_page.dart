// shot_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../controllers/ble_manager.dart';


class ShotPage extends StatefulWidget {
  // initialPins: List<bool> where true = pin is STANDING before this shot
  final List<bool> initialPins;
  final int shotNumber;
  // shotIndex within the frame (1-based). This determines whether the strike/spare
  // button is an 'X' (first shot) or '/' (second shot).
  final int frameShotIndex;
  // Allow caller to specify initial dropdown/picker values so selections
  // persist across shots when provided by the caller.
  final int? initialBoard;
  final int? initialLane;
  final int? initialBall;
  final double? initialSpeed;
  // If true, start the page in the post-shot editing phase so pins are editable immediately
  final bool startInPost;
  // Optional initial outcome (e.g. 'X', '/', 'F') to pre-select the outcome button
  final String? initialOutcome;
  // Optional initial foul flag
  final bool? initialIsFoul;

  const ShotPage({
    super.key,
    required this.initialPins,
    required this.shotNumber,
    required this.frameShotIndex,
    this.initialBoard,
    this.initialLane,
    this.initialBall,
    this.initialSpeed,
    this.startInPost = false,
    this.initialOutcome,
    this.initialIsFoul,
  });


 @override
 State<ShotPage> createState() => _ShotPageState();
}


enum Phase { pre, post }


class _ShotPageState extends State<ShotPage> {
 // true = pin is STANDING (i.e., not yet knocked down in this shot)
 late List<bool> currentPinsState;
 String? selectedOutcome;
 bool isFoul = false;
 Phase _phase = Phase.pre;


 // Pre-shot controls
 double _sliderPos = 21; // slider value 1..40, start so stance maps to 20
 int get _stance => 41 - _sliderPos.round(); // maps so left shows 40, right shows 1
  int _selectedBoard = 1;
  int _selectedLane = 1;
  int _selectedBall = 1;
 bool _isRecording = false;


 // Post-shot controls
 double _ballSpeed = 12.0;


 @override
 void initState() {
   super.initState();
   // Copy the initial pins standing (up) into the mutable state
   currentPinsState = List.from(widget.initialPins);
    // Initialize the dropdowns/picker from passed-in initial values when provided
    if (widget.initialBoard != null) _selectedBoard = widget.initialBoard!;
    if (widget.initialLane != null) _selectedLane = widget.initialLane!;
    if (widget.initialBall != null) _selectedBall = widget.initialBall!;
    if (widget.initialSpeed != null) _ballSpeed = widget.initialSpeed!;
    // If caller provided initial post-shot data (editing an existing shot), prefill
    // the outcome / foul / pins so the post-phase shows the correct state when the
    // user navigates to it. IMPORTANT: do NOT force the UI into post-phase so users
    // still see the pre-shot controls first and can access both phases.
    if (widget.startInPost) {
      // Pre-select outcome if provided (X, /, F)
      if (widget.initialOutcome != null) {
        selectedOutcome = widget.initialOutcome;
        if (selectedOutcome == 'X' || selectedOutcome == '/') {
          // For X or / we assume all pins were knocked down
          currentPinsState = List.filled(10, false);
        }
      }
      if (widget.initialIsFoul != null) {
        isFoul = widget.initialIsFoul!;
        if (isFoul) {
          // For fouls, keep pins as the initialPins (no pins knocked down)
          currentPinsState = List.from(widget.initialPins);
        }
      }
    }
 }


 @override
 Widget build(BuildContext context) {
   final mq = MediaQuery.of(context).size;
   final uiScale = (math.min(mq.width, mq.height) / 320.0).clamp(0.5, 1.0) * 0.72;
 final preScale = uiScale * 1.18;


   return Scaffold(
     backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
     extendBodyBehindAppBar: true,
     body: SafeArea(
       child: Padding(
         padding: EdgeInsets.only(top: 6.0 * uiScale, left: 8 * uiScale, right: 8 * uiScale),
         child: Column(
           mainAxisAlignment: MainAxisAlignment.start,
           crossAxisAlignment: CrossAxisAlignment.center,
           children: [
            Text(
                       'Shot ${widget.frameShotIndex}',
               style: TextStyle(
                 color: Colors.white,
                 fontSize: 17 * uiScale,
                 fontWeight: FontWeight.bold,
               ),
             ),
             SizedBox(height: 6 * uiScale),


             if (_phase == Phase.pre) ...[
               // Make pins a bit bigger on pre-shot to occupy more space (slightly reduced)
               _buildPinDisplay(small: false, scale: preScale * 1.02, selectable: false),
               SizedBox(height: 1 * uiScale),
               _buildStanceSlider(scale: preScale),
               SizedBox(height: 0.5 * uiScale),
               // Wider dropdowns with smaller gaps; bring them closer to the slider
               _buildDropdownRow(scale: preScale, itemWidth: 80 * preScale, gap: 4 * preScale, itemHeight: 34 * preScale, backgroundColor: const Color.fromRGBO(90, 90, 110, 1)),
               SizedBox(height: 0.0 * uiScale),
               Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   _buildRecordButton(scale: preScale * 1.25, round: true),
                   SizedBox(width: 2 * preScale),
                   _buildNextPhaseButton(scale: preScale * 1.25, round: true),
                 ],
               ),
             ] else ...[
               // Post-shot: pins (dominant), left side strike/spare + foul, right side two blanks, horizontal speed picker near bottom
               Expanded(
                 child: Column(
                   children: [
                     Flexible(
                       // pins + picker grouped together so picker sits immediately under pins
                       flex: 1,
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Row(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Expanded(child: Align(alignment: Alignment.topCenter, child: _buildPinDisplay(numbered: true, scale: uiScale * 2.35, selectable: true))),
                             ],
                           ),
                           // place picker immediately under pins inside same flexible area
                           _buildHorizontalSpeedPicker(scale: uiScale),
                         ],
                       ),
                     ),


                     // Bottom action row directly under the speed picker: Back, Strike/Spare, G/F, Submit
                     Transform.translate(
                       // nudge the button row down a bit (less negative) so it's slightly lower on screen
                       offset: Offset(0, 2 * uiScale),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           _buildBackToPreButton(scale: uiScale * 1.0),
                           SizedBox(width: 0.6 * uiScale),
                           _buildStrikeOrSpareButton(scale: uiScale * 1.0),
                           SizedBox(width: 0.6 * uiScale),
                           _buildFoulGutterButton(scale: uiScale * 1.0),
                           SizedBox(width: 0.6 * uiScale),
                           _buildSubmitButton(context, scale: uiScale * 1.0),
                         ],
                       ),
                     ),
                   ],
                 ),
               ),
             ],
           ],
         ),
       ),
     ),
   );
 }


 void _togglePin(int index) {
   setState(() {
     // Toggle the state of the pin (standing <-> down),
     // but ONLY if the pin was standing before this shot.
     if (widget.initialPins[index]) {
       currentPinsState[index] = !currentPinsState[index];
     }
   });
 }


 void _nextPhase() async {
   // Stop recording if it's active
   if (_isRecording) {
     // 🔥 Send BLE command to stop recording on phone
     await BLEManager().sendRecordingCommand("stopRec");
     setState(() => _isRecording = false);
   }

   setState(() {
     // Default to the frame-relative symbol: first shot shows 'X', second shows '/'
     // when entering post-phase, so the user sees the appropriate symbol by default.
     selectedOutcome = widget.frameShotIndex == 1 ? 'X' : '/';
     isFoul = false;

     _phase = Phase.post;
   });
 }


 void _backToPre() {
   setState(() {
     _phase = Phase.pre;
   });
 }


 void _selectOutcome(String outcome) {
   setState(() {
     // Toggle selection
     selectedOutcome = selectedOutcome == outcome ? null : outcome;
     isFoul = false;


     // Auto-set pins based on standard outcomes
     if (selectedOutcome == "X") {
       // Strike: All pins standing initially are now DOWN (false)
       currentPinsState = List.filled(10, false);
     } else if (selectedOutcome == "/") {
       // Spare: All pins standing initially are now DOWN (false)
       currentPinsState = List.filled(10, false);
     } else if (selectedOutcome == "F") {
       // Foul: All pins standing initially are still STANDING (true)
       currentPinsState = List.from(widget.initialPins);
       isFoul = true;
     } else {
       // Reset to initial state if outcome is unselected or custom count is chosen
       currentPinsState = List.from(widget.initialPins);
     }
   });
 }


 void _submitShot(BuildContext context) {
   // 1. Determine final pins standing (true=standing)
   // Pins that were already down (false in initialPins) must remain down (false in currentPinsState).
   // The currentPinsState already handles this logic within _togglePin and _selectOutcome,
   // as it represents the pin state AFTER the shot relative to the initial state.
  
   final List<bool> pinsStanding = currentPinsState;


   // 2. Calculate pins knocked down (Count)
   // Count = (Pins standing initially) - (Pins standing now)
   final int initialStandingCount = widget.initialPins.where((p) => p).length;
   final int currentStandingCount = pinsStanding.where((p) => p).length;
   final int pinsDownCount = initialStandingCount - currentStandingCount;
  
   Navigator.pop(context, {
     'pinsStanding': pinsStanding, // true = standing (for the leaveType bitmask)
     'pinsDownCount': pinsDownCount, // # of pins knocked down (Count)
     'outcome': selectedOutcome, // (Position)
     'isFoul': isFoul,
     // include the pre/post selections so the caller can update its UI
     'stance': _stance,
     'board': _selectedBoard,
     'lane': _selectedLane,
     'ball': _selectedBall,
     'speed': _ballSpeed,
   });
 }
  Widget _buildPinDisplay({bool small = false, bool numbered = false, double scale = 1.0, bool selectable = true}) {
   List<List<int>> pinRows = [
     [7, 8, 9, 10],
     [4, 5, 6],
     [2, 3],
     [1],
   ];


 double pinSize = (small ? 18.0 : 28.0) * scale;


   return Column(
     mainAxisSize: MainAxisSize.min,
     children: pinRows.map((row) {
       return Padding(
         padding: const EdgeInsets.symmetric(vertical: 0.5),
         child: Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: row.map((pin) => numbered ? _buildPinNumbered(pin, size: pinSize, selectable: selectable) : _buildPin(pin, size: pinSize, selectable: selectable)).toList(),
         ),
       );
     }).toList(),
   );
 }


 Widget _buildPin(int pinNumber, {double size = 31.0, bool selectable = true}) {
   int index = pinNumber - 1;
   // Pin is UP (standing) if currentPinsState[index] is true
   bool isStanding = currentPinsState[index];
   // Pin is editable ONLY if it was standing initially
   bool isEditable = selectable && widget.initialPins[index];


   return GestureDetector(
     onTap: isEditable ? () => _togglePin(index) : null,
     child: Container(
       width: size,
       height: size,
       margin: EdgeInsets.symmetric(horizontal: size * 0.04, vertical: size * 0.01),
       decoration: BoxDecoration(
         color: isStanding ? const Color.fromRGBO(142, 124, 195, 1) : const Color.fromRGBO(153, 153, 153, 1),
         shape: BoxShape.circle,
         border: Border.all(
           color: isEditable ? Colors.black : Colors.black.withOpacity(0.4),
           width: 0.7,
         ),
       ),
     ),
   );
 }


 Widget _buildPinNumbered(int pinNumber, {double size = 31.0, bool selectable = true}) {
   int index = pinNumber - 1;
   bool isStanding = currentPinsState[index];
   bool isEditable = selectable && widget.initialPins[index];


   return GestureDetector(
     onTap: isEditable ? () => _togglePin(index) : null,
     child: Container(
       width: size,
       height: size,
       margin: EdgeInsets.symmetric(horizontal: size * 0.04, vertical: size * 0.01),
       decoration: BoxDecoration(
         color: isStanding ? const Color.fromRGBO(142, 124, 195, 1) : const Color.fromRGBO(153, 153, 153, 1),
         shape: BoxShape.circle,
         border: Border.all(
           color: isEditable ? Colors.black : Colors.black.withOpacity(0.4),
           width: 0.8,
         ),
       ),
       alignment: Alignment.center,
       child: Text(
         pinNumber.toString(),
           style: TextStyle(
             color: isStanding ? Colors.white : Colors.black87,
             fontSize: size * 0.36,
             fontWeight: FontWeight.bold,
           ),
       ),
     ),
   );
 }


 // --- New UI helpers ---
 Widget _buildStanceSlider({double scale = 1.0}) {
 // Compact, trackless slider: show only thumb and tick marks with longer width.
 final parentWidth = MediaQuery.of(context).size.width;
 // Make slider as long as possible on the watch
 final width = (parentWidth * 0.995) * scale;


   return Column(
     children: [
       // Row with end labels and centered stance value on the same line
       SizedBox(
         width: width,
         child: Row(
           crossAxisAlignment: CrossAxisAlignment.center,
           children: [
             Text('40', style: TextStyle(color: Colors.white, fontSize: 16 * scale, fontWeight: FontWeight.bold)),
             Expanded(child: Center(child: Text('Stance: $_stance', style: TextStyle(color: Colors.white, fontSize: 13 * scale, fontWeight: FontWeight.w600)))),
             Text('1', style: TextStyle(color: Colors.white, fontSize: 16 * scale, fontWeight: FontWeight.bold)),
           ],
         ),
       ),
       SizedBox(height: 2 * scale),
       // Longer slider with larger thumb. We'll draw major ticks (every 5) with a CustomPaint overlay
       SizedBox(
         width: width,
         height: 44 * scale,
         child: Stack(
           alignment: Alignment.center,
           children: [
             // Custom paint draws major ticks every 5 units
             CustomPaint(
               size: Size(width, 44 * scale),
               painter: _MajorTickPainter(scale: scale),
             ),
             SliderTheme(
               data: SliderTheme.of(context).copyWith(
                 trackHeight: 0,
                 activeTrackColor: Colors.transparent,
                 inactiveTrackColor: Colors.transparent,
                 thumbShape: RoundSliderThumbShape(enabledThumbRadius: 16 * scale, disabledThumbRadius: 16 * scale),
                 overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
                 // hide built-in tick marks (we draw our own)
                 tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 0),
                 activeTickMarkColor: Colors.transparent,
                 inactiveTickMarkColor: Colors.transparent,
                 showValueIndicator: ShowValueIndicator.never,
               ),
               child: Slider(
                 value: _sliderPos,
                 min: 1,
                 max: 40,
                 divisions: 39,
                 onChanged: (v) => setState(() => _sliderPos = v),
               ),
             ),
           ],
         ),
       ),
     ],
   );


   // (old slider variant removed)
 }


 Widget _buildDropdownRow({double scale = 1.0, double itemWidth = 48.0, double gap = 6.0, double itemHeight = 36.0, Color? backgroundColor}) {
   final items = List<int>.generate(40, (i) => i + 1);
   Widget dd(int value, ValueChanged<int?> onChanged) => Container(
         width: itemWidth,
         height: itemHeight,
         padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 2 * scale),
         decoration: BoxDecoration(color: backgroundColor ?? const Color.fromRGBO(0, 0, 0, 0), borderRadius: BorderRadius.circular(6 * scale)),
         child: DropdownButton<int>(
           isExpanded: true,
           isDense: true,
           value: value,
           dropdownColor: const Color.fromRGBO(67, 67, 67, 1),
           underline: const SizedBox.shrink(),
           items: items
               .map((i) => DropdownMenuItem(value: i, child: Text(i.toString(), style: TextStyle(color: Colors.white, fontSize: 14 * scale))))
               .toList(),
           onChanged: onChanged,
         ),
       );


   return Row(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
       Column(children: [Text('Board', style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.w600)), dd(_selectedBoard, (v) => setState(() => _selectedBoard = v ?? 1))]),
       SizedBox(width: gap),
       Column(children: [Text('Lane', style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.w600)), dd(_selectedLane, (v) => setState(() => _selectedLane = v ?? 1))]),
       SizedBox(width: gap),
       Column(children: [Text('Ball', style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.w600)), dd(_selectedBall, (v) => setState(() => _selectedBall = v ?? 1))]),
     ],
   );
 }


Widget _buildRecordButton({double scale = 1.0, bool round = false}) {
  Future<void> handleTap() async {
    // If currently recording, stop and send command
    if (_isRecording) {
      await BLEManager().sendRecordingCommand("stopRec");
      setState(() => _isRecording = false);
    } else {
      // Start recording
      setState(() => _isRecording = true);
      await BLEManager().sendRecordingCommand("startRec");
    }
  }

  if (round) {
    return GestureDetector(
      onTap: handleTap,
      child: CircleAvatar(
        radius: 18 * scale,
        backgroundColor: _isRecording ? Colors.redAccent : Colors.red,
        child: Icon(
          _isRecording ? Icons.stop : Icons.fiber_manual_record,
          color: Colors.white,
          size: 18 * scale,
        ),
      ),
    );
  }

  final Color btnBg = _isRecording
      ? Colors.redAccent
      : const Color.fromRGBO(153, 153, 153, 1);

  return GestureDetector(
    onTap: handleTap,
    child: Container(
      width: 44 * scale,
      height: 28 * scale,
      decoration: BoxDecoration(
        color: btnBg,
        border: Border.all(color: Colors.black),
      ),
      alignment: Alignment.center,
      child: Icon(
        _isRecording ? Icons.stop : Icons.fiber_manual_record,
        color: Colors.white,
        size: 16 * scale,
      ),
    ),
  );
}


 Widget _buildNextPhaseButton({double scale = 1.0, bool round = false}) {
   if (round) {
     return IconButton(
       icon: Icon(Icons.arrow_forward, color: Colors.white, size: 20 * scale),
       onPressed: () => _nextPhase(),
       splashRadius: 18 * scale,
     );
   }


   return GestureDetector(
     onTap: () => _nextPhase(),
     child: Container(
       width: 44 * scale,
       height: 28 * scale,
       decoration: BoxDecoration(color: const Color.fromRGBO(153, 153, 153, 1), border: Border.all(color: Colors.black)),
       alignment: Alignment.center,
       child: Icon(Icons.arrow_forward, color: Colors.white, size: 18 * scale),
     ),
   );
 }


 Widget _buildStrikeOrSpareButton({double scale = 1.0}) {
  final String compact = widget.frameShotIndex == 1 ? 'X' : '/';
   final double w = 64 * scale;
   final double h = 44 * scale;
   // Simple toggle button (no popup) for Strike/Spare — tapping toggles the outcome
  final bool isSelected = selectedOutcome == compact;
  final Color bg = isSelected ? const Color.fromRGBO(80, 200, 120, 1) : const Color.fromRGBO(153, 153, 153, 1);
  final Color textColor = isSelected ? Colors.black : Colors.white;

  return GestureDetector(
    onTap: () => _selectOutcome(compact),
    child: Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: bg, border: Border.all(color: Colors.black, width: 0.6 * scale)),
      alignment: Alignment.center,
      child: Text(compact, style: TextStyle(color: textColor, fontSize: 14 * scale, fontWeight: FontWeight.w700)),
    ),
  );
 }


 Widget _buildFoulGutterButton({double scale = 1.0}) {
   return PopupMenuButton<String>(
     color: const Color.fromRGBO(67, 67, 67, 1),
     onSelected: (s) {
       setState(() {
         // Both Foul and Gutter indicate no pins were hit: restore all initial standing pins
         currentPinsState = List.from(widget.initialPins);
         if (s == 'Foul') {
           selectedOutcome = 'F';
           isFoul = true;
         } else if (s == 'Gutter') {
           // Gutter: no pins were knocked down; clear outcome selection but keep pins up
           selectedOutcome = null;
           isFoul = false;
         }
       });
     },
     itemBuilder: (_) => [
       const PopupMenuItem(value: 'Foul', child: Text('Foul', style: TextStyle(color: Colors.white))),
       const PopupMenuItem(value: 'Gutter', child: Text('Gutter', style: TextStyle(color: Colors.white))),
     ],
     child: Container(
       width: 64 * scale,
       height: 44 * scale,
       padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 4 * scale),
       decoration: BoxDecoration(color: const Color.fromRGBO(153, 153, 153, 1), border: Border.all(color: Colors.black, width: 0.6 * scale)),
       alignment: Alignment.center,
       child: Text('G/F', style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.w700)),
     ),
   );
 }


 // placeholder buttons removed — function kept commented in case we need it later
 // Widget _buildPlaceholderButton({double scale = 1.0}) {
 //   return Container(
 //     width: 36 * scale,
 //     height: 36 * scale,
 //     decoration: BoxDecoration(border: Border.all(color: Colors.black), color: const Color.fromRGBO(153, 153, 153, 1)),
 //     alignment: Alignment.center,
 //   );
 // }


 Widget _buildHorizontalSpeedPicker({double scale = 1.0}) {
   const double itemWidth = 40;
   final controller = ScrollController(initialScrollOffset: 0);
   return Padding(
     // restore small vertical padding so the picker spacing matches prior layout
     padding: EdgeInsets.symmetric(vertical: 2.0 * scale),
     child: Column(
       children: [
         Text(
           'Speed',
           style: TextStyle(
             color: Colors.white,
             fontSize: 13 * scale,
             fontWeight: FontWeight.w500,
           ),
         ),
         SizedBox(height: 0.0 * scale),


         LayoutBuilder(
           builder: (context, constraints) {
             final visibleWidth = constraints.maxWidth;


             void centerOnValue(int index) {
               final targetOffset = (index * itemWidth) - (visibleWidth / 2) + (itemWidth / 2);
               controller.animateTo(
                 targetOffset.clamp(
                   controller.position.minScrollExtent,
                   controller.position.maxScrollExtent,
                 ),
                 duration: const Duration(milliseconds: 250),
                 curve: Curves.easeOut,
               );
             }


             final values = List<int>.generate(351, (i) => i + 50);
             final currentValue = (_ballSpeed * 10).round().clamp(values.first, values.last);


             // center the selected value after layout so it sits in the middle
             WidgetsBinding.instance.addPostFrameCallback((_) {
               final idx = ((_ballSpeed * 10).round() - values.first);
               centerOnValue(idx.clamp(0, values.length - 1));
             });


             return Container(
               // restore a slightly larger height so the picker visuals match previous spacing
               height: 28 * scale,
               width: constraints.maxWidth, // extend full available width
               decoration: BoxDecoration(
                 gradient: const LinearGradient(
                   begin: Alignment.centerLeft,
                   end: Alignment.centerRight,
                   colors: [
                     Color(0xFF3A3A3A),
                     Color(0xFF5B5B5B),
                     Color(0xFFDADADA),
                     Color(0xFF5B5B5B),
                     Color(0xFF3A3A3A),
                   ],
                   stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                 ),
               ),
               child: ClipRRect(
                 borderRadius: BorderRadius.circular(6 * scale),
                 child: ShaderMask(
                   shaderCallback: (rect) {
                     return const LinearGradient(
                       begin: Alignment.centerLeft,
                       end: Alignment.centerRight,
                       colors: [
                         Colors.transparent,
                         Colors.white,
                         Colors.white,
                         Colors.transparent,
                       ],
                       stops: [0.0, 0.12, 0.88, 1.0],
                     ).createShader(rect);
                   },
                   blendMode: BlendMode.dstIn,
                   child: ListView.builder(
                     controller: controller,
                     scrollDirection: Axis.horizontal,
                     physics: const BouncingScrollPhysics(),
                     itemCount: values.length,
                     itemBuilder: (context, i) {
                       final isSelected = values[i] == currentValue;


                           return GestureDetector(
                         onTap: () {
                           setState(() => _ballSpeed = values[i] / 10.0);
                           centerOnValue(i);
                         },
                         child: Container(
                           width: itemWidth,
                           alignment: Alignment.center,
                           decoration: BoxDecoration(
                             border: Border(
                               right: BorderSide(
                                 color: Colors.black.withOpacity(0.2),
                                 width: 0.8,
                               ),
                             ),
                           ),
                           child: Text(
                             (values[i] / 10.0).toStringAsFixed(1),
                             style: TextStyle(
                               color: isSelected ? Colors.black : Colors.black.withOpacity(0.45),
                               fontSize: isSelected ? 14 * scale : 11 * scale,
                               fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                             ),
                           ),
                         ),
                       );
                     },
                   ),
                 ),
               ),
             );
           },
         ),
       ],
     ),
   );
 }


 Widget _buildBackToPreButton({double scale = 1.0}) {
   // Smaller back button so it sits closer to the other action buttons.
   return GestureDetector(
     onTap: _backToPre,
     child: Container(
       width: 44 * scale,
       height: 34 * scale,
       decoration: BoxDecoration(
         color: Colors.transparent,
       ),
       alignment: Alignment.center,
       child: Icon(Icons.arrow_back, color: Colors.white, size: 18 * scale),
     ),
   );
 }


 Widget _buildSubmitButton(BuildContext context, {double scale = 1.0}) {
   final double w = 64 * scale;
   final double h = 44 * scale;
   return Container(
     width: w,
     height: h,
     decoration: BoxDecoration(
       color: const Color.fromRGBO(153, 153, 153, 1),
       border: Border.all(color: Colors.black, width: 0.6 * scale),
     ),
     child: TextButton(
       onPressed: () => _submitShot(context),
       style: TextButton.styleFrom(
         padding: EdgeInsets.zero,
         foregroundColor: Colors.white,
         shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.zero,
         ),
       ),
       child: Text(
         'Submit',
         style: TextStyle(
           fontSize: 13 * scale,
           fontWeight: FontWeight.w600,
           color: Colors.white,
         ),
       ),
     ),
   );
 }


}


// Painter that draws major tick marks every 5 units along the slider width
class _MajorTickPainter extends CustomPainter {
 final double scale;
 _MajorTickPainter({required this.scale});


 @override
 void paint(Canvas canvas, Size size) {
   final paint = Paint()
     ..color = Colors.white
     ..strokeWidth = 2.0 * scale
     ..strokeCap = StrokeCap.round;


   const int min = 1;
   const int max = 40;
   // Add a small horizontal padding so ticks line up visually with the end labels
   final double pad = 6.0 * scale;
   final double avail = math.max(0.0, size.width - 2 * pad);


   // draw ticks at 5,10,...,40
   for (int v = 5; v <= max; v += 5) {
     double norm = (v - min) / (max - min);
     final double x = pad + norm * avail;
     // Center the tick marks vertically inside the slider area (slightly tighter)
     final double top = size.height * 0.40;
     final double bottom = size.height * 0.60;
     canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
   }
 }


 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
