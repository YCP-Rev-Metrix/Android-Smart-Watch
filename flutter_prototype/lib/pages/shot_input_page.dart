import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:get/get.dart';
import '../controllers/ble_manager.dart';
import '../controllers/packet_queue.dart';
import '../controllers/session_controller.dart';
import '../models/shot.dart';
import '../models/account_packet.dart';

class ShotInputPage extends StatefulWidget {
  final List<bool> initialPins;
  final List<Shot> recentShots;
  final int shotNumber;
  final int frameShotIndex;
  final int frameNumber;
  final int initialLane;
  final double initialImpact;
  final int initialBall;
  final double initialSpeed;
  final double initialStance;
  final double initialTarget;
  final double initialBreakPoint;
  final bool startInPost;
  final bool? initialIsFoul;
  final List<Ball>? balls;

  const ShotInputPage({
    super.key,
    required this.initialPins,
    required this.recentShots,
    required this.shotNumber,
    required this.frameShotIndex,
    required this.frameNumber,
    required this.initialLane,
    required this.initialImpact,
    required this.initialBall,
    required this.initialSpeed,
    required this.initialStance,
    required this.initialTarget,
    required this.initialBreakPoint,
    required this.startInPost,
    this.initialIsFoul,
    this.balls,
  });

  @override
  State<ShotInputPage> createState() => _ShotInputPageState();
}

class _ShotInputPageState extends State<ShotInputPage> {
  final PageController _pageController = PageController();
  late ScrollController _speedScrollController;
  int _currentPage = 0;
  int _selectedBall = 1;
  int _selectedBoard = 5;
  bool isFoul = false;
  double _selectedSpeed = 15;
  int _selectedSpeedInt = 15; // Integer part of speed (5-40)
  int _selectedSpeedDecimal = 0; // Decimal part of speed (0-9)
  late List<bool> _selectedPins;
  String? _selectedOutcome;
  bool _isRecording = false;
  // Timer? _recordingTimer;
  double _selectedStance = 20.0;
  int _selectedLane = 1;
  double _sliderPos = 20;
  int get _stance => 40 - _sliderPos.round();
  double _targetBoard = 20.0;
  double _breakpointBoard = 20.0;
  late List<String> _recentBoards;
  late List<String> _recentStances;

  final List<String> _titles = [
    'Recent Results',
    'Select Ball',
    'Record',
    'Shot',
    'Impact',
    'Boards',
    'Speed',
  ];

  final List<String> _firstShotBoardOptions = [
    'Left',
    'Brooklyn',
    'Nose',
    'High',
    'High pocket',
    'Pocket',
    'Light pocket',
    'Light',
    'Right',
  ];

  final List<String> _secondShotBoardOptions = [
    'Right',
    'Left',
    'Chop',
    'Tap',
    'Gutter',
    'Foul',
  ];

  List<String> get _boardOptions => widget.frameShotIndex == 1
      ? _firstShotBoardOptions
      : _secondShotBoardOptions;

  final List<double> _speedOptions = List.generate(
    101,
    (index) => 10.0 + (index * 0.1),
  );

  String _impactLabelFromValue(double boardValue) {
    String titleCase(String value) {
      return value
          .split(' ')
          .where((word) => word.isNotEmpty)
          .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
    }

    int nearestIndex = 0;
    double nearestDelta = double.infinity;

    for (int i = 0; i < _boardOptions.length; i++) {
      final double optionBoard;
      if (widget.frameShotIndex == 1) {
        optionBoard = Shot.impactToBoard(_boardOptions[i]).toDouble();
      } else {
        optionBoard = Shot.secondShotImpactToBoard(_boardOptions[i]).toDouble();
      }
      
      final delta = (optionBoard - boardValue).abs();
      if (delta < nearestDelta) {
        nearestDelta = delta;
        nearestIndex = i;
      }
    }

    if (_boardOptions.isEmpty) return '';
    return titleCase(_boardOptions[nearestIndex]);
  }

  String _stanceLabelFromValue(double stanceValue) {
    if (stanceValue % 1 == 0) {
      return stanceValue.toInt().toString();
    }
    return stanceValue.toStringAsFixed(1);
  }

  List<String> _buildRecentImpactLabels() {
    final labels = widget.recentShots
        .take(3)
        .map((shot) => _impactLabelFromValue(shot.impact))
        .toList();
    while (labels.length < 3) {
      labels.add('');
    }
    return labels;
  }

  List<String> _buildRecentStanceLabels() {
    final labels = widget.recentShots
        .take(3)
        .map((shot) => _stanceLabelFromValue(shot.stance))
        .toList();
    while (labels.length < 3) {
      labels.add('');
    }
    return labels;
  }

  @override
  void initState() {
    super.initState();
    // Initialize pins to all false (all knocked down by default, user selects which to leave standing)
    // _selectedPins always represents which pins are LEFT STANDING (true = standing)
    _selectedPins = List.filled(10, false);
    _speedScrollController = ScrollController();
    _speedScrollController.addListener(_onSpeedScroll);
    
    // Initialize from widget parameters
    _selectedBall = widget.initialBall;
    
    // Ensure selected ball exists in the available balls list; fallback to first ball if not found
    if (widget.balls != null && widget.balls!.isNotEmpty) {
      final ballExists = widget.balls!.any((b) => b.id == _selectedBall);
      if (!ballExists) {
        _selectedBall = widget.balls!.first.id;
      }
    }
    if (widget.startInPost) {
      _selectedBoard = _resolveInitialImpactIndex(widget.initialImpact);
    } else {
      // For first shot, default to Pocket
      if (widget.frameShotIndex == 1) {
        _selectedBoard = _boardOptions.indexOf('Pocket');
      } else {
        // For second shot, default to Tap
        _selectedBoard = _boardOptions.indexOf('Tap');
      }
    }
    _selectedLane = widget.initialLane;
    _selectedSpeed = widget.initialSpeed;
    _selectedSpeedInt = widget.initialSpeed.truncate();
    _selectedSpeedDecimal = ((widget.initialSpeed - widget.initialSpeed.truncate()) * 10).round();
    _selectedStance = widget.initialStance;
    _targetBoard = widget.initialTarget;
    _breakpointBoard = widget.initialBreakPoint;
    _recentBoards = _buildRecentImpactLabels();
    _recentStances = _buildRecentStanceLabels();
    _sliderPos = (40 - widget.initialStance).toDouble().clamp(1.0, 39.0);
    if (widget.initialIsFoul == true) {
      isFoul = true;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Scroll to the initial speed after the view is built
      if (_speedScrollController.hasClients) {
        final itemCenterOffset = (50 * 50.0) + 25; // Center of the 50th item
        final screenCenterOffset = itemCenterOffset - (_speedScrollController.position.viewportDimension / 2);
        _speedScrollController.jumpTo(screenCenterOffset);
      }
    });
  }

  Future<void> _showBoardPickerDialog(
    String label,
    double currentValue,
    ValueChanged<double> onSelected,
    {int maxWholeBoard = 40}
  ) async {
    int intPart = currentValue.truncate();
    int decPart = ((currentValue - intPart) * 10).round(); // 0 or 5

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            const double itemHeight = 40;
            const double wheelHeight = 160;

            Widget buildWheel({
              required List<int> values,
              required int selected,
              required ValueChanged<int> onTap,
              required Alignment alignment,
              required EdgeInsets textPadding,
            }) {
              final controller = ScrollController();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final idx = values.indexOf(selected);
                if (controller.hasClients && idx >= 0) {
                  controller.jumpTo(
                    (idx * itemHeight).clamp(
                      0.0,
                      ((values.length - 1) * itemHeight).toDouble(),
                    ),
                  );
                }
              });

              return SizedBox(
                height: wheelHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.15, 0.92, 1.0],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: controller,
                      physics: const BouncingScrollPhysics(),
                      itemCount: values.length + 2,
                      itemBuilder: (ctx, i) {
                        if (i == 0) return const SizedBox(height: itemHeight);
                        if (i == values.length + 1) {
                          return const SizedBox(height: wheelHeight - itemHeight);
                        }
                        final idx2 = i - 1;
                        final value = values[idx2];
                        final isSel = value == selected;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => onTap(value));
                            final targetOffset = (idx2 * itemHeight).clamp(
                              0.0,
                              ((values.length - 1) * itemHeight).toDouble(),
                            );
                            controller.animateTo(
                              targetOffset,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          },
                          child: Container(
                            height: itemHeight,
                            alignment: alignment,
                            padding: textPadding,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black.withOpacity(0.2),
                                  width: 0.8,
                                ),
                              ),
                            ),
                            child: Text(
                              '$value',
                              style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.45),
                                fontSize: isSel ? 28 : 20,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.normal,
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

            final intValues =
              List<int>.generate(maxWholeBoard, (i) => maxWholeBoard - i); // max..1
            final decValues = [5, 0]; // 0.5 then 0.0

            return AlertDialog(
              backgroundColor: const Color.fromRGBO(80, 80, 80, 1),
              titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              title: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 200,
                height: wheelHeight + 20,
                child: Row(
                  children: [
                    Expanded(
                      child: buildWheel(
                        values: intValues,
                        selected: intPart,
                        onTap: (v) => intPart = v,
                        alignment: Alignment.centerRight,
                        textPadding: const EdgeInsets.only(right: 4),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, right: 4, top: 18),
                      child: Text(
                        '.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: buildWheel(
                        values: decValues,
                        selected: decPart,
                        onTap: (v) => decPart = v,
                        alignment: Alignment.centerLeft,
                        textPadding: const EdgeInsets.only(left: 4),
                      ),
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(60, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    side: const BorderSide(
                      color: Colors.white60,
                      width: 2,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    final selectedValue = intPart + decPart / 10.0;
                    final bounded = selectedValue.clamp(1.0, maxWholeBoard.toDouble());
                    onSelected(bounded.toDouble());
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(60, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    side: const BorderSide(
                      color: Color.fromRGBO(250, 136, 71, 1),
                      width: 2,
                    ),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(color: Color.fromRGBO(250, 136, 71, 1), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _togglePin(int index) {
    setState(() {
      // Shot 1: all pins can be toggled
      // Shot 2: only pins that were standing after shot 1 can be toggled
      if (widget.frameShotIndex == 1 || widget.initialPins[index]) {
        _selectedPins[index] = !_selectedPins[index];
      }
    });
  }

  void _selectOutcome(String outcome) {
    setState(() {
      _selectedOutcome = _selectedOutcome == outcome ? null : outcome;
      isFoul = false; // Clear foul state when selecting strike/spare
      if (_selectedOutcome == 'X' || _selectedOutcome == '/') {
        // Strike/Spare: ALL pins knocked down = none left standing
        _selectedPins = List.filled(10, false);
      } 
      else if (_selectedOutcome == "F") {
        // Foul: no pins knocked down, all available pins still standing
        if (widget.frameShotIndex == 1) {
          _selectedPins = List.filled(10, true);
        } else {
          _selectedPins = List.from(widget.initialPins);
        }
        isFoul = true;
      }
      else if (_selectedOutcome == null) {
        // Deselected: reset to no pins selected
        _selectedPins = List.filled(10, false);
      }
    });
  }

  void _onSpeedScroll() {
    // Calculate which item is in the center
    final centerOffset = _speedScrollController.offset + (_speedScrollController.position.viewportDimension / 2);
    final itemIndex = (centerOffset / 50.0).round().clamp(0, _speedOptions.length - 1);
    
    // Update selected speed
    setState(() {
      _selectedSpeed = _speedOptions[itemIndex];
    });
    
    // If scrolling stopped, snap to the item
    if (!_speedScrollController.position.isScrollingNotifier.value) {
      final itemCenterOffset = (itemIndex * 50.0) + 25;
      final targetOffset = itemCenterOffset - (_speedScrollController.position.viewportDimension / 2);
      _speedScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
            children: row.map((pin) => _buildPinNumbered(pin, size: pinSize, selectable: selectable)).toList(),
          ),
        );
      }).toList(),
    );
  }

 Widget _buildPinNumbered(int pinNumber, {double size = 31.0, bool selectable = true}) {
   int index = pinNumber - 1;
   bool isSelected = _selectedPins[index];
   // On shot 1: all pins are editable
   // On shot 2: only pins that were standing after shot 1 are editable
   bool isEditable = selectable && (widget.frameShotIndex == 1 || widget.initialPins[index]);
   
   // Determine pin color:
   // - If not editable (knocked down in previous shot): dark grey
   // - If strike/spare selected: all pins appear knocked down (dark grey)
   // - Shot 1: unselected = light slate grey, selected = light blue
   // - Shot 2: available pins start light blue, selected (left standing) = orange
   Color pinColor;
   
   // If strike/spare/foul is selected, show knocked down appearance
   if (_selectedOutcome == 'X' || _selectedOutcome == '/' || _selectedOutcome == 'F') {
     pinColor = !isEditable || !isSelected
         ? const Color.fromRGBO(100, 100, 100, 1) // dark grey - knocked down
         : (widget.frameShotIndex == 1 
             ? const Color.fromRGBO(51, 83, 156, 1) // Shot 1: foul shows light blue (standing)
             : const Color.fromRGBO(250, 136, 71, 1)); // Shot 2: foul shows orange (standing)
   } else if (!isEditable) {
     pinColor = const Color.fromRGBO(100, 100, 100, 1); // dark grey - knocked down previous shot
   } else if (widget.frameShotIndex == 1) {
     // Shot 1
     pinColor = isSelected 
       ? const Color.fromRGBO(51, 83, 156, 1) // light blue - selected as standing
       : const Color.fromRGBO(119, 136, 153, 1); // light slate grey - will be knocked down
   } else {
     // Shot 2: inverted colors - knocked down pins are light blue, standing pins are orange
     pinColor = isSelected 
       ? const Color.fromRGBO(250, 136, 71, 1) // orange - left standing on shot 2
       : const Color.fromRGBO(51, 83, 156, 1); // light blue - knocked down on shot 2
   }

   return GestureDetector(
     onTap: isEditable ? () => _togglePin(index) : null,
     child: Container(
       width: size,
       height: size,
       margin: EdgeInsets.symmetric(horizontal: size * 0.04, vertical: size * 0.01),
       decoration: BoxDecoration(
         color: pinColor,
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
             color: isSelected ? Colors.white : Colors.black87,
             fontSize: size * 0.36,
             fontWeight: FontWeight.bold,
           ),
       ),
     ),
   );
 }

  Widget _buildStrikeOrSpareButton({double scale = 1.0}) {
    final String compact = widget.frameShotIndex == 1 ? 'X' : '/';
    final double w = 64 * scale;
    final double h = 44 * scale;
    final bool isSelected = _selectedOutcome == compact;
    final Color bg = const Color.fromRGBO(250, 136, 71, 1);
    final Color textColor = isSelected ? Colors.white : Colors.white;

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
     color: const Color.fromRGBO(18, 26, 36, 1),
     onSelected: (s) {
       setState(() {
         // Both Foul and Gutter mean no pins knocked down: all available pins stay standing
         if (widget.frameShotIndex == 1) {
           _selectedPins = List.filled(10, true);
         } else {
           _selectedPins = List.from(widget.initialPins);
         }
         if (s == 'Foul') {
           _selectedOutcome = 'F';
           isFoul = true;
         } else if (s == 'Gutter') {
           // Gutter: no pins were knocked down; outcome is '-'
           _selectedOutcome = '-';
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
       decoration: BoxDecoration(color: const Color.fromRGBO(250, 136, 71, 1), border: Border.all(color: Colors.black, width: 0.6 * scale)),
       alignment: Alignment.center,
       child: Text('-/F', style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.w700)),
     ),
   );
 }
 Widget _buildRecordButton({double scale = 1.0, bool round = false}) {
  Future<void> handleTap() async {
    // If currently recording, stop and send command
    if (_isRecording) {
      await _stopRecording();
    } else {
      // Start recording
      setState(() => _isRecording = true);
      await Get.find<BLEManager>().sendRecordingCommand("startRec");
      // Auto-stop after 30 seconds
      //_recordingTimer = Timer(const Duration(seconds: 30), () {
      //  _stopRecording();
      //});
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
      : const Color.fromRGBO(208, 220, 232, 1);

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
Widget _buildStanceSlider({double scale = 1.0}) {
 // Compact, trackless slider: show only thumb and tick marks with longer width.
 final parentWidth = MediaQuery.of(context).size.width;
 final width = (parentWidth * 0.85) * scale;
 final thumbRadius = 12.0 * scale;
 // Match slider's internal padding: thumb center moves from thumbRadius to (width - thumbRadius)
 final pad = thumbRadius;
 final avail = math.max(0.0, width - 2 * pad);

   return Column(
     children: [
       // Row with end labels only
       SizedBox(
         width: width,
         child: Row(
           crossAxisAlignment: CrossAxisAlignment.center,
           children: [
             Text('39', style: TextStyle(color: Colors.white, fontSize: 12 * scale, fontWeight: FontWeight.bold)),
             const Spacer(),
             Text('1', style: TextStyle(color: Colors.white, fontSize: 12 * scale, fontWeight: FontWeight.bold)),
           ],
         ),
       ),
       SizedBox(height: 0 * scale),
       SizedBox(
         width: width,
         height: 32 * scale,
         child: Stack(
           alignment: Alignment.center,
           children: [
             // Draws major ticks every 5 units
             CustomPaint(
               size: Size(width, 32 * scale),
               painter: _MajorTickPainter(scale: scale, pad: pad, availWidth: avail),
             ),
             SliderTheme(
               data: SliderTheme.of(context).copyWith(
                 trackHeight: 0,
                 activeTrackColor: Colors.transparent,
                 inactiveTrackColor: Colors.transparent,
                 thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12 * scale, disabledThumbRadius: 12 * scale),
                 overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
                 // hide built-in tick marks
                 tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 0),
                 activeTickMarkColor: Colors.transparent,
                 inactiveTickMarkColor: Colors.transparent,
                 showValueIndicator: ShowValueIndicator.never,
               ),
               child: Slider(
                 value: _sliderPos,
                 min: 1,
                 max: 39,
                 divisions: 38,
                 onChanged: (v) => setState(() => _sliderPos = v),
               ),
             ),
           ],
         ),
       ),
     ],
   );
 }

  @override
  void dispose() {
    _pageController.dispose();
    _speedScrollController.removeListener(_onSpeedScroll);
    _speedScrollController.dispose();
    // _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      // _recordingTimer?.cancel();
      // _recordingTimer = null;
      await Get.find<BLEManager>().sendRecordingCommand("stopRec");
      setState(() => _isRecording = false);
    }
  }

  void _onPageChanged(int page) {
    // Stop recording when changing pages
    _stopRecording();
    setState(() {
      _currentPage = page;
    });
  }

   int _calculatePinsDown() {
    final initialStanding = widget.initialPins.where((p) => p).length;
    final currentStanding = _selectedPins.where((p) => p).length;
    return initialStanding - currentStanding;
  }

  int _resolveInitialImpactIndex(double boardValue) {
    if (boardValue == 0) return 0; // If impact is 0
    final mappedIdx = _boardOptions.indexWhere(
      (impact) {
        if (widget.frameShotIndex == 1) {
          return Shot.impactToBoard(impact).toDouble() == boardValue;
        } else {
          return Shot.secondShotImpactToBoard(impact).toDouble() == boardValue;
        }
      }
    );
    if (mappedIdx != -1) {
      return mappedIdx;
    }

    final fallback = _boardOptions.indexOf('Pocket');
    return fallback != -1 ? fallback : 0;
  }

  void _submit() {
    final pinsDownCount = _calculatePinsDown();
    
    double impactBoard = 0.0;
    if (_selectedOutcome == '/' || _selectedOutcome == 'F' || _selectedOutcome == '-') {
      // Impact is 0 when spare, foul, or gutter/miss
      if (_selectedOutcome == '/' && widget.frameShotIndex == 2) {
        // Spare on shot 2: use value 7
        impactBoard = 7.0;
      } else if (_selectedOutcome == 'F' && widget.frameShotIndex == 2) {
        // Foul on shot 2: use value 6
        impactBoard = 6.0;
      } else if (_selectedOutcome == '-' && widget.frameShotIndex == 2) {
        // Gutter on shot 2: use value 5
        impactBoard = 5.0;
      } else {
        // Shot 1 or default: impact 0
        impactBoard = 0.0;
      }
    } else {
      if (_boardOptions.isNotEmpty && _selectedBoard < _boardOptions.length) {
        final selectedImpact = _boardOptions[_selectedBoard];
        if (widget.frameShotIndex == 1) {
          impactBoard = Shot.impactToBoard(selectedImpact).toDouble();
        } else {
          impactBoard = Shot.secondShotImpactToBoard(selectedImpact).toDouble();
        }
      }
    }

    // Build the Shot model from all collected input data
    final shot = Shot(
      shotNumber: widget.shotNumber,
      ball: _selectedBall,
      numOfPinsKnocked: pinsDownCount,
      pins: Shot.buildPins(standingPins: _selectedPins, isFoul: isFoul),
      impact: impactBoard,
      stance: _selectedStance,
      target: _targetBoard,
      breakPoint: _breakpointBoard,
      speed: _selectedSpeed,
      frameNum: widget.frameNumber,
      lane: _selectedLane,
    );

    // Print the completed Shot object to the console
    // ignore: avoid_print
    print('Shot submitted: ${shot.toJson()}');

    // Add the shot to the FCFS packet queue
    PacketQueue.instance.enqueue(shot);

    // Note: Shot packet is sent from session_controller.dart after the shot is recorded
    // with the updated game score (via _sendShotPacket)

    Navigator.of(context).pop({
      'pinsStanding': _selectedPins,
      'pinsDownCount': pinsDownCount,
      'outcome': _selectedOutcome,
      'isFoul': isFoul,
      'stance': _selectedStance,
      'target': _targetBoard,
      'breakPoint': _breakpointBoard,
      'impact': impactBoard,
      'board': impactBoard,
      'lane': _selectedLane,
      'ball': _selectedBall,
      'speed': _selectedSpeed,
    });
  }

  bool get _shouldSkipImpactPage => _selectedOutcome == '/' || _selectedOutcome == 'F' || _selectedOutcome == '-';

  /// Builds lane dropdown items based on the lanes count from AccountPacket
  List<DropdownMenuItem<int>> _buildLaneDropdownItems() {
    final bleManager = Get.find<BLEManager>();
    final packet = bleManager.lastAccountPacket.value;
    final laneCount = packet?.lanes ?? 2;
    
    return List.generate(
      laneCount,
      (index) {
        final laneNumber = index + 1;
        return DropdownMenuItem(
          value: laneNumber,
          child: Text(
            laneNumber.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(18, 26, 36, 1),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: _shouldSkipImpactPage ? 6 : 7,
        itemBuilder: (context, index) {
          // If we are skipping the impact page, shift indices after it
          int effectiveIndex = index;
          if (_shouldSkipImpactPage && index >= 4) {
            effectiveIndex = index + 1;
          }

          if (effectiveIndex == 1) {
            // Ball selector page
            final effectiveBalls = (widget.balls != null && widget.balls!.isNotEmpty)
                ? widget.balls!
                : List.generate(4, (i) => Ball(id: i + 1, name: 'Ball ${i + 1}'));
            final selectedIndex = effectiveBalls.indexWhere((b) => b.id == _selectedBall);
            final safeSelectedIndex = selectedIndex >= 0 ? selectedIndex : 0;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(51, 83, 156, 1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildVerticalListPicker(
                            items: effectiveBalls.map((b) => b.name).toList(),
                            selectedIndex: safeSelectedIndex,
                            onSelectionChanged: (i) {
                              setState(() => _selectedBall = effectiveBalls[i].id);
                            },
                            labelFormatter: (i) => effectiveBalls[i].name,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else if (effectiveIndex == 2) {
            // Record page with record button
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 5),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(51, 83, 156, 1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRecordButton(scale: 3.5, round: true),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            );
          } else if (effectiveIndex == 3) {
            // Shot screen with pins and outcome
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(51, 83, 156, 1),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pin Display - larger scale
                      _buildPinDisplay(scale: 1.3),
                      // Outcome buttons - smaller and closer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStrikeOrSpareButton(scale: 0.60),
                          _buildFoulGutterButton(scale: 0.60),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else if (effectiveIndex == 4) {
            // Impact selector page
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(51, 83, 156, 1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildVerticalListPicker(
                            items: _boardOptions,
                            selectedIndex: _selectedBoard,
                            onSelectionChanged: (i) {
                              setState(() => _selectedBoard = i);
                            },
                            labelFormatter: (i) => _boardOptions[i],
                            itemHeight: 60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else if (effectiveIndex == 5) {
            // Boards/Stance page with stance/target/breakpoint and lane
            Widget boardRow(String label, double value, VoidCallback onTap) {
              final displayVal = value % 1 == 0
                  ? '${value.toInt()}'
                  : value.toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(250, 136, 71, 1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color.fromRGBO(250, 136, 71, 1), width: 1),
                        ),
                        child: Text(
                          displayVal,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 16),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(51, 83, 156, 1),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                boardRow('Stance', _selectedStance, () async {
                  await _showBoardPickerDialog(
                    'Stance',
                    _selectedStance,
                    (v) => setState(() => _selectedStance = v),
                    maxWholeBoard: 50,
                  );
                }),
                const SizedBox(height: 4),
                boardRow('Target', _targetBoard, () async {
                  await _showBoardPickerDialog(
                    'Target',
                    _targetBoard,
                    (v) => setState(() => _targetBoard = v),
                    maxWholeBoard: 40,
                  );
                }),
                const SizedBox(height: 4),
                boardRow('Breakpoint', _breakpointBoard, () async {
                  await _showBoardPickerDialog(
                    'Breakpoint',
                    _breakpointBoard,
                    (v) => setState(() => _breakpointBoard = v),
                    maxWholeBoard: 40,
                  );
                }),
                const SizedBox(height: 6),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Horizontal divider line
                      Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        height: 1,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 12),
                    // Lane dropdown (horizontal layout)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lane',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 0),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(90, 90, 90, 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButton<int>(
                            value: _selectedLane,
                            dropdownColor: const Color.fromRGBO(80, 80, 80, 1),
                            underline: const SizedBox(),
                            isDense: true,
                            items: _buildLaneDropdownItems(),
                            onChanged: (value) {
                              setState(() {
                                _selectedLane = value ?? 1;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            );
          } else if (effectiveIndex == 4) {
            // Shot screen with pins and outcome
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(135, 206, 235, 1),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pin Display - larger scale
                      _buildPinDisplay(scale: 1.3),
                      // Outcome buttons - smaller and closer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStrikeOrSpareButton(scale: 0.60),
                          _buildFoulGutterButton(scale: 0.60),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else if (effectiveIndex == 5) {
            // Impact selector page
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(135, 206, 235, 1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildVerticalListPicker(
                            items: _boardOptions,
                            selectedIndex: _selectedBoard,
                            onSelectionChanged: (i) {
                              setState(() => _selectedBoard = i);
                            },
                            labelFormatter: (i) => _boardOptions[i],
                            itemHeight: 60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else if (effectiveIndex == 6) {
            // Speed selector page with dual vertical pickers
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(51, 83, 156, 1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _buildDualSpeedPickers(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(80, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      side: const BorderSide(
                        color: Color.fromRGBO(250, 136, 71, 1),
                        width: 2,
                      ),
                    ),
                    onPressed: _submit,
                    child: const Text('Submit', style: TextStyle(fontSize: 12, color: Color.fromRGBO(250, 136, 71, 1), fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            );
          } else if (effectiveIndex == 3) {
            // Record page with record button
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 5),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(135, 206, 235, 1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRecordButton(scale: 3.5, round: true),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            );
          } else if (effectiveIndex == 0) {
            // Recent Results page - info only
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 15, bottom: 10),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(51, 83, 156, 1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Last 3 Impacts
                          Text(
                            'Last 3 Impacts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._recentBoards.map((board) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              board,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          )),
                          const SizedBox(height: 10),
                          // Last 3 Stances
                          Text(
                            'Last 3 Stances',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._recentStances.map((stance) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              stance,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 10),
                  child: Text(
                    _titles[effectiveIndex],
                    style: const TextStyle(
                      color: Color.fromRGBO(51, 83, 156, 1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildDualSpeedPickers() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left picker for integer part (5-40)
        Expanded(
          child: _buildSpeedIntPicker(),
        ),
        // Decimal point between pickers
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, top: 18),
          child: Text(
            '.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Right picker for decimal part (0-9)
        Expanded(
          child: _buildSpeedDecimalPicker(),
        ),
      ],
    );
  }

  Widget _buildSpeedIntPicker() {
    const double itemHeight = 40;
    final controller = ScrollController();
    final intValues = List<int>.generate(26, (i) => 30 - i); // 30 to 5 (reversed)

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleHeight = constraints.maxHeight;

        void centerOnValue(int index) {
          final targetOffset = (index * itemHeight);
          controller.animateTo(
            targetOffset.clamp(
              controller.position.minScrollExtent,
              controller.position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final idx = 30 - _selectedSpeedInt; // Reversed index
          if (idx >= 0 && idx < intValues.length) {
            centerOnValue(idx);
          }
        });

        return Container(
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.15, 0.85, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: controller,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                itemCount: intValues.length + 2, // +2 for top/bottom padding
                itemBuilder: (context, i) {
                  // Add minimal padding at top to align selected value with decimal point
                  if (i == 0) {
                    return SizedBox(height: itemHeight);
                  }
                  // Add padding at bottom
                  if (i == intValues.length + 1) {
                    return SizedBox(height: visibleHeight - itemHeight);
                  }

                  final itemIndex = i - 1;
                  final value = intValues[itemIndex];
                  final isSelected = value == _selectedSpeedInt;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSpeedInt = value;
                        _selectedSpeed = _selectedSpeedInt + (_selectedSpeedDecimal / 10.0);
                      });
                      centerOnValue(itemIndex);
                    },
                    child: Container(
                      height: itemHeight,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.black.withOpacity(0.2),
                            width: 0.8,
                          ),
                          left: BorderSide(
                            color: Colors.transparent,
                            width: 50,
                          ),
                        ),
                      ),
                      child: Text(
                        value.toString(),
                        style: TextStyle(
                          color: isSelected ? const Color.fromRGBO(250, 136, 71, 1) : Colors.white,
                          fontSize: isSelected ? 28 : 20,
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
    );
  }

  Widget _buildSpeedDecimalPicker() {
    const double itemHeight = 40;
    final controller = ScrollController();
    final decimalValues = List<int>.generate(10, (i) => 9 - i); // 9 to 0 (reversed)

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleHeight = constraints.maxHeight;

        void centerOnValue(int index) {
          final targetOffset = (index * itemHeight);
          controller.animateTo(
            targetOffset.clamp(
              controller.position.minScrollExtent,
              controller.position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final idx = 9 - _selectedSpeedDecimal; // Reversed index
          if (idx >= 0 && idx < decimalValues.length) {
            centerOnValue(idx);
          }
        });

        return Container(
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.15, 0.85, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: controller,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                itemCount: decimalValues.length + 2, // +2 for top/bottom padding
                itemBuilder: (context, i) {
                  // Add minimal padding at top to align selected value with decimal point
                  if (i == 0) {
                    return SizedBox(height: itemHeight);
                  }
                  // Add padding at bottom
                  if (i == decimalValues.length + 1) {
                    return SizedBox(height: visibleHeight - itemHeight);
                  }

                  final itemIndex = i - 1;
                  final value = decimalValues[itemIndex];
                  final isSelected = value == _selectedSpeedDecimal;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSpeedDecimal = value;
                        _selectedSpeed = _selectedSpeedInt + (_selectedSpeedDecimal / 10.0);
                      });
                      centerOnValue(itemIndex);
                    },
                    child: Container(
                      height: itemHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.black.withOpacity(0.2),
                            width: 0.8,
                          ),
                          right: BorderSide(
                            color: Colors.transparent,
                            width: 50,
                          ),
                        ),
                      ),
                      child: Text(
                        value.toString(),
                        style: TextStyle(
                          color: isSelected ? const Color.fromRGBO(250, 136, 71, 1) : Colors.white,
                          fontSize: isSelected ? 28 : 20,
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
    );
  }

  Widget _buildVerticalListPicker({
    required List<String> items,
    required int selectedIndex,
    required Function(int) onSelectionChanged,
    required String Function(int) labelFormatter,
    double itemHeight = 60,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final visibleHeight = constraints.maxHeight;
          final initialOffset = (selectedIndex * itemHeight).clamp(0.0, (items.length - 1) * itemHeight);
          final controller = ScrollController(initialScrollOffset: initialOffset);

          void centerOnValue(int index) {
            final targetOffset = (index * itemHeight);
            controller.animateTo(
              targetOffset.clamp(
                controller.position.minScrollExtent,
                controller.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }

          final currentValue = selectedIndex;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            centerOnValue(selectedIndex); // Direct index, no +1
          });

          return Container(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            decoration: const BoxDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
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
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length + 2,
                  itemBuilder: (context, i) {
                    // Add padding at top
                    if (i == 0) {
                      return SizedBox(height: itemHeight);
                    }
                    // Add padding at bottom
                    if (i == items.length + 1) {
                      return SizedBox(height: visibleHeight - itemHeight);
                    }
                    
                    final itemIndex = i - 1;
                    final isSelected = itemIndex == currentValue;

                    return GestureDetector(
                      onTap: () {
                        onSelectionChanged(itemIndex);
                        centerOnValue(itemIndex);
                      },
                      child: Container(
                        height: itemHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.black.withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                        ),
                        child: Text(
                          labelFormatter(itemIndex),
                          style: TextStyle(
                            color: isSelected ? const Color.fromRGBO(250, 136, 71, 1) : Colors.white,
                            fontSize: isSelected ? 22 : 17,
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
    );
  }
}
class _MajorTickPainter extends CustomPainter {
 final double scale;
 final double pad;
 final double availWidth;
 
 _MajorTickPainter({required this.scale, required this.pad, required this.availWidth});

 @override
 void paint(Canvas canvas, Size size) {
   final paint = Paint()
     ..color = Colors.white
     ..strokeWidth = 2.0 * scale
     ..strokeCap = StrokeCap.round;

   // Draw ticks at stance positions 39, 35, 30, 25, 20, 15, 10, 5, 1
   // Slider uses min=1, max=39 (38 divisions)
   // SliderPos = 40 - stance, norm = (sliderPos - 1) / 38
   final stanceValues = [39, 35, 30, 25, 20, 15, 10, 5, 1];
   for (int stance in stanceValues) {
     final sliderPos = 40 - stance;
     final norm = (sliderPos - 1) / 38.0;
     final double x = pad + norm * availWidth;
     final double top = size.height * 0.40;
     final double bottom = size.height * 0.60;
     canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
   }
 }

 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}