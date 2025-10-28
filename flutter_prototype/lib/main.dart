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

class BowlingShot extends StatelessWidget {
  final Color color;
  final int frameIndex;
  final int shotIndex;
  const BowlingShot({
    super.key,
    required this.color,
    required this.frameIndex,
    required this.shotIndex,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonWidth = size.width * 0.75;
    final largeHeight = size.height * 0.25;
    final smallHeight = size.height * 0.15;

    return Scaffold(
      backgroundColor: color,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Frame ${frameIndex + 1} — Shot $shotIndex',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: size.height * 0.04),
              _ModernButton(
                label: "Pins",
                width: buttonWidth,
                height: largeHeight,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PinsPage()),
                ),
              ),
              SizedBox(height: size.height * 0.04),
              _ModernButton(
                label: "Other",
                width: buttonWidth,
                height: smallHeight,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OtherPage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernButton extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _ModernButton({
    required this.label,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(2, 2),
              blurRadius: 6,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade900,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class PinsPage extends StatelessWidget {
  const PinsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SubPage(title: "Pins", color: Colors.grey.shade100);
  }
}

class OtherPage extends StatelessWidget {
  const OtherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SubPage(title: "Other", color: Colors.grey.shade200);
  }
}

class _SubPage extends StatelessWidget {
  final String title;
  final Color color;

  const _SubPage({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: color,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$title Page',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: size.height * 0.05),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Back to Shot"),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
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
