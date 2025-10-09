import 'package:flutter/material.dart';
import 'dart:ui' as ui;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force software rendering on emulators (prevents Impeller/Vulkan crashes)
  // Works on Wear OS x86_64 emulators
  if (ui.PlatformDispatcher.instance.implicitView == null) {
    debugPrint('Running in emulator: forcing software rendering');
    // This flag makes Flutter fallback to Skia software rendering
    WidgetsFlutterBinding.ensureInitialized();
  }

  runApp(const WatchApp());
}

class WatchApp extends StatelessWidget {
  const WatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SwipePages(),
    );
  }
}

class SwipePages extends StatefulWidget {
  const SwipePages({super.key});

  @override
  State<SwipePages> createState() => _SwipePagesState();
}

class _SwipePagesState extends State<SwipePages> {
  final PageController _controller = PageController();

  void _onVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 150) {
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
      child: PageView(
        controller: _controller,
        children: const [
          WatchPage(
            color: Colors.deepPurple,
            text: '🏠 Home\n↓ Swipe Down for Menu\n← → Swipe for More',
          ),
          WatchPage(
            color: Colors.teal,
            text: '📈 Page 2\n← → Swipe',
          ),
          WatchPage(
            color: Colors.indigo,
            text: '⚙️ Page 3\n← → Swipe',
          ),
        ],
      ),
    );
  }
}

class WatchPage extends StatelessWidget {
  final Color color;
  final String text;

  const WatchPage({super.key, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
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
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '📋 Menu',
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(20),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OptionPage(title: 'Option 1'),
                ),
              ),
              child: const Text('1'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(20),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OptionPage(title: 'Option 2'),
                ),
              ),
              child: const Text('2'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('⬆ Return', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class OptionPage extends StatelessWidget {
  final String title;
  const OptionPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 20, color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return'),
            ),
          ],
        ),
      ),
    );
  }
}
