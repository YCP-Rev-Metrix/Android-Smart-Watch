import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:watch_app/pages/frame_page.dart';
import 'package:watch_app/pages/game_page.dart';

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
        scaffoldBackgroundColor: Color.fromRGBO(67, 67, 67, 1),
        canvasColor: Color.fromRGBO(67, 67, 67, 1),
        colorScheme: const ColorScheme.dark(
          background: Color.fromRGBO(67, 67, 67, 1),
          surface: Color.fromRGBO(67, 67, 67, 1),
        ),
      ),
      home: FrameShell(),
    );
  }
}