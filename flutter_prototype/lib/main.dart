import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (ui.PlatformDispatcher.instance.implicitView == null) {
    debugPrint('Running in emulator: forcing software rendering');
  }

  runApp(const BowlingWatch());
}

class BowlingWatch extends StatelessWidget {
  const BowlingWatch({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FrameShell(),
    );
  }
}

class FrameShell extends StatefulWidget {
  const FrameShell({super.key});

  @override
  State<FrameShell> createState() => _FrameShellState();
}

class _FrameShellState extends State<FrameShell> {
  int _activeFrame = 0;
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
      _activeFrame = index;
      _frameSelectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _frameSelectMode,
      child: GestureDetector(
        onLongPress: _enterFrameSelection,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BowlingFrame(
              color: frameColors[_activeFrame],
              index: _activeFrame,
            ),
            if (_frameSelectMode)
              FrameSelectionOverlay(
                activeFrame: _activeFrame,
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


class BowlingFrame extends StatefulWidget {
  final Color color;
  final int index;
  const BowlingFrame({super.key, required this.color, required this.index});

  @override
  State<BowlingFrame> createState() => _BowlingFrameState();
}

class _BowlingFrameState extends State<BowlingFrame> {
  final PageController _controller = PageController();

  void _onVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MenuPage()),
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
          BowlingShot(color: widget.color, frameIndex: widget.index, shotIndex: 1),
          BowlingShot(color: widget.color.withOpacity(0.85), frameIndex: widget.index, shotIndex: 2),
        ],
      ),
    );
  }
}

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

class BowlingShot extends StatefulWidget {
  final int frameIndex;
  final int shotIndex;
  final Color color;

  const BowlingShot({
    super.key,
    required this.frameIndex,
    required this.shotIndex,
    required this.color,
  });

  @override
  State<BowlingShot> createState() => _BowlingShotState();
}

class _BowlingShotState extends State<BowlingShot> {
  List<bool> pins = List.filled(10, false);
  int lane = 1;
  int board = 18;
  double speed = 15.0;
  int ball = 1;


@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Color.fromRGBO(67, 67, 67, 1),
    body: Center(
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (_) => ShotPage(
                initialPins: List.from(pins),
                frameNumber: widget.frameIndex + 1,
              ),
            ),
          );
          if (result != null) {
            setState(() => pins = result['pins'] as List<bool>);
          }
        },
        child: Container(
          width: 280,
          height: 280,
          decoration: const BoxDecoration(
            color: Color.fromRGBO(67, 67, 67, 1),
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Frame ${widget.frameIndex + 1} — Shot ${widget.shotIndex}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildPinDisplay(pins),
              const SizedBox(height: 6),

              // 👇 Info Bar (Data Section)
              GestureDetector(
                onTap: () async {
                  final updatedInfo = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OtherPage(
                        lane: lane,
                        board: board,
                        speed: speed,
                        shotNumber: widget.shotIndex,
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
                },
                child: Transform.scale(
                  scale: 0.8,
                  child: _buildInfoBar(lane, board, speed, 1),
                ),
              ),
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
    final isDown = pins[index];
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

  Widget _buildInfoBar(int lane, int board, double speed, int ball, {double height = 50}) {
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
}

// -------------------- ShotPage --------------------
class ShotPage extends StatefulWidget {
  final List<bool> initialPins;
  final int frameNumber;

  const ShotPage({super.key, required this.initialPins, required this.frameNumber});

  @override
  State<ShotPage> createState() => _ShotPageState();
}

class _ShotPageState extends State<ShotPage> {
  late List<bool> pins;
  String? selectedOutcome;

  @override
  void initState() {
    super.initState();
    pins = List.from(widget.initialPins);
  }

  void _togglePin(int index) {
    setState(() {
      pins[index] = !pins[index];
    });
  }

  void _selectOutcome(String outcome) {
    setState(() {
      selectedOutcome = selectedOutcome == outcome ? null : outcome;
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Color.fromRGBO(67, 67, 67, 1),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Text(
            'Frame ${widget.frameNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Pins (no circular container)
          _buildPinDisplay(),
          const SizedBox(height: 10),

          // Outcome buttons
          _buildOutcomeButtons(),
          const SizedBox(height: 10),

          // Submit
          _buildSubmitButton(context),
        ],
      ),
    ),
  );
}


  // ---------------- Pin Display ----------------
  Widget _buildPinDisplay() {
    List<List<int>> pinRows = [
      [7, 8, 9, 10],
      [4, 5, 6],
      [2, 3],
      [1],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: pinRows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((pin) => _buildPin(pin)).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPin(int pinNumber) {
    int index = pinNumber - 1;
    bool isDown = pins[index];
    return GestureDetector(
      onTap: () => _togglePin(index),
      child: Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: isDown
              ? const Color.fromRGBO(153, 153, 153, 1)
              : const Color.fromRGBO(142, 124, 195, 1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 0.5),
        ),
      ),
    );
  }

  // ---------------- Outcome Buttons ----------------
  Widget _buildOutcomeButtons() {
    return Column(
      children: [
        _buildOutcomeBox("Strike"),
        const SizedBox(height: 6),
        _buildOutcomeBox("Spare"),
        const SizedBox(height: 6),
        _buildOutcomeBox("Foul"),
      ],
    );
  }

  Widget _buildOutcomeBox(String label) {
    final bool isSelected = selectedOutcome == label;

    return GestureDetector(
      onTap: () => _selectOutcome(label),
      child: Container(
        width: 100,
        height: 20,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromRGBO(142, 124, 195, 1)
              : const Color.fromRGBO(153, 153, 153, 1),
          border: Border.all(color: Colors.black, width: 0.6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ---------------- Submit Button ----------------
  Widget _buildSubmitButton(BuildContext context) {
    return Container(
      width: 80,
      height: 15,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(153, 153, 153, 1),
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: TextButton(
        onPressed: () {
          Navigator.pop(context, {
            'pins': pins,
            'outcome': selectedOutcome,
          });
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.black,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
        child: const Text(
          'Submit',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.normal,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}


// -------------------- OtherPage --------------------
class OtherPage extends StatefulWidget {
  final int lane;
  final int board;
  final double speed;
  final int shotNumber;

  const OtherPage({
    super.key,
    required this.lane,
    required this.board,
    required this.speed,
    required this.shotNumber,
  });

  @override
  State<OtherPage> createState() => _OtherPageState();
}

class _OtherPageState extends State<OtherPage> {
  late int lane;
  late int board;
  late double speed;

  final double _itemWidth = 40;

  @override
  void initState() {
    super.initState();
    lane = widget.lane;
    board = widget.board;
    speed = widget.speed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(67, 67, 67, 1),
      body: SafeArea(
        child: Center(
          
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 1),
              Text(
                'Shot ${widget.shotNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              
              _buildHorizontalPicker(
                label: 'Lane',
                currentValue: lane,
                values: List.generate(10, (i) => i + 1),
                onChanged: (v) => setState(() => lane = v),
              ),
              _buildHorizontalPicker(
                label: 'Board',
                currentValue: board,
                values: List.generate(39, (i) => i + 1),
                onChanged: (v) => setState(() => board = v),
              ),
              _buildHorizontalPicker(
                label: 'Speed',
                currentValue: (speed * 10).round(),
                values: List.generate(351, (i) => (i + 50)), // 5.0 → 40.0 (×10)
                onChanged: (v) => setState(() => speed = v / 10.0),
              ),
              const SizedBox(height: 2),
              Container(
                width: 80,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(153, 153, 153, 1),
                  border: Border.all(color: Colors.black, width: 0.5),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    {'lane': lane, 'board': board, 'speed': speed},
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: Colors.black,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero, // square corners
                    ),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.normal,
                      color: Colors.black
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalPicker({
  required String label,
  required int currentValue,
  required List<int> values,
  required ValueChanged<int> onChanged,
}) {
  final controller = ScrollController(
    initialScrollOffset: (currentValue - values.first) * _itemWidth,
  );

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 1),

        LayoutBuilder(
          builder: (context, constraints) {
            final visibleWidth = constraints.maxWidth;

            void centerOnValue(int index) {
              final targetOffset =
                  (index * _itemWidth) - (visibleWidth / 2) + (_itemWidth / 2);
              controller.animateTo(
                targetOffset.clamp(
                  controller.position.minScrollExtent,
                  controller.position.maxScrollExtent,
                ),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }

            return Container(
              height: 20,
              width: 260,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF3A3A3A), // darkest edges
                    Color(0xFF5B5B5B),
                    Color(0xFFDADADA), // bright center highlight
                    Color(0xFF5B5B5B),
                    Color(0xFF3A3A3A),
                  ],
                  stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
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
                          onChanged(values[i]);
                          centerOnValue(i);
                        },
                        child: Container(
                          width: _itemWidth,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: Colors.black.withOpacity(0.2),
                                width: 0.8, // thin vertical line
                              ),
                            ),
                          ),
                          child: Text(
                            label == 'Speed'
                                ? (values[i] / 10.0).toStringAsFixed(1)
                                : values[i].toString(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.black.withOpacity(0.4),
                              fontSize: isSelected ? 13 : 10,
                              fontWeight: isSelected
                                  ? FontWeight.normal
                                  : FontWeight.bold
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
}


class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(67, 67, 67, 1),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.grey.shade900,
          ),
          child: const Text('⬆ Return'),
        ),
      ),
    );
  }
}
