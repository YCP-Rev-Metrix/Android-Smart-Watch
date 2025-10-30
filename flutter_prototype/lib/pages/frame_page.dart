import 'package:flutter/material.dart';
import 'package:watch_app/pages/game_page.dart';
import 'shot_page.dart';
import 'other_page.dart';
import 'package:flutter/services.dart';
import '../controllers/session_manager.dart';
final session = SessionManager();

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
                      child: Builder(builder: (context) {
                        final session = SessionManager();
                        final score = session.getFrameScore(i);

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Frame ${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Score: $score',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      }),

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
final session = SessionManager();

late List<bool> pins;
late int lane;
late int board;
late double speed;

@override
void initState() {
  super.initState();
  final shotData = session.getShot(widget.frameIndex, widget.shotIndex);
  pins = List<bool>.from(shotData['pins']);
  lane = shotData['lane'];
  board = shotData['board'];
  speed = shotData['speed'];
}


@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Color.fromRGBO(67, 67, 67, 1),
    extendBodyBehindAppBar: true,
    body: Center(
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (_) => ShotPage(
                initialPins: List.from(pins),
                shotNumber: widget.shotIndex,
              ),
            ),
          );

          if (result != null) {
            setState(() {
              pins = result['pins'] as List<bool>;
            });
            session.updateShot(widget.frameIndex, widget.shotIndex, {
              'pins': pins,
              'lane': lane,
              'board': board,
              'speed': speed,
            });
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
                  session.updateShot(widget.frameIndex, widget.shotIndex, {
                    'pins': pins,
                    'lane': lane,
                    'board': board,
                    'speed': speed,
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