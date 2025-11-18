// main.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:watch_app/pages/frame_page.dart';
// import 'package:watch_app/controllers/session_controller.dart'; 

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromRGBO(67, 67, 67, 1),
        canvasColor: const Color.fromRGBO(67, 67, 67, 1),
        colorScheme: const ColorScheme.dark(
          background: Color.fromRGBO(67, 67, 67, 1),
          surface: Color.fromRGBO(67, 67, 67, 1),
        ),
      ),
      // Assuming FrameShell is the starting page for the watch app UI
      home: const FrameShell(),
    );
  }
}