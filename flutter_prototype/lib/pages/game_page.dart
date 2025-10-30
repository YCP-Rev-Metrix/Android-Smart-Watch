import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'frame_page.dart';
import 'dev_settings_page.dart';

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int _activeGame = 0;
  bool _gameSelectMode = false;

  final List<Color> gameColors = [
    Colors.grey.shade900,
    Colors.grey.shade800,
    Colors.grey.shade700,
  ];

  void _enterGameSelection() {
    HapticFeedback.selectionClick();
    setState(() => _gameSelectMode = true);
  }

  void _exitGameSelection() {
    setState(() => _gameSelectMode = false);
  }

  void _selectGame(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _activeGame = index;
      _gameSelectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _gameSelectMode,
      child: GestureDetector(
        onLongPress: _enterGameSelection,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BowlingGame(
              color: gameColors[_activeGame],
              index: _activeGame,
            ),
            if (_gameSelectMode)
              GameSelectionOverlay(
                activeGame: _activeGame,
                colors: gameColors,
                onSelect: _selectGame,
                onCancel: _exitGameSelection,
              ),
          ],
        ),
      ),
    );
  }
}

class BowlingGame extends StatefulWidget {
  final Color color;
  final int index;
  const BowlingGame({super.key, required this.color, required this.index});

  @override
  State<BowlingGame> createState() => _BowlingGameState();
}

class _BowlingGameState extends State<BowlingGame> {
  void _onVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    // Swipe down → go to FrameShell
    if (details.primaryVelocity! > 200) {
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FrameShell()),
      );
    }

    // Swipe up → go back (pop to previous screen)
    else if (details.primaryVelocity! < -200) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DevSettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: _onVerticalSwipe,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: widget.color,
        body: Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(
              color: Color.fromRGBO(67, 67, 67, 1),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Game ${widget.index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Score: 000',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _openSettings,
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white70,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameSelectionOverlay extends StatefulWidget {
  final int activeGame;
  final List<Color> colors;
  final ValueChanged<int> onSelect;
  final VoidCallback onCancel;

  const GameSelectionOverlay({
    super.key,
    required this.activeGame,
    required this.colors,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  State<GameSelectionOverlay> createState() => _GameSelectionOverlayState();
}

class _GameSelectionOverlayState extends State<GameSelectionOverlay> {
  late final PageController _controller;
  late int _selected;
  bool _isSettling = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.activeGame;
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

  void _onTapGame(int i) {
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
                    onTap: () => _onTapGame(i),
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
                        'Game ${i + 1}',
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
