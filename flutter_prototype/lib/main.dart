// main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'controllers/ble_manager.dart';
import 'pages/frame_page.dart';     // or your main page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize BLE manager early
  Get.put(BLEManager());

  // Start app
  runApp(const RevMetrixApp());
}

class RevMetrixApp extends StatelessWidget {
  const RevMetrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'RevMetrix Watch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      home: const StartupWrapper(),
    );
  }
}

/// Ensures GATT/foreground service start before showing the UI
class StartupWrapper extends StatefulWidget {
  const StartupWrapper({super.key});

  @override
  State<StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends State<StartupWrapper> {
  final ble = Get.find<BLEManager>();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    initializeBLE();
  }

  Future<void> initializeBLE() async {
    // 1. Initialize GATT server (service + characteristics)
    await ble.initGattServer();

    // 2. Start foreground service to keep BLE alive
    await startForegroundBleService();

    await ble.startAdvertising();
  
  // Add a small delay to ensure advertising starts
    await Future.delayed(Duration(milliseconds: 500));

    setState(() {
      ready = true;
    });
  }

  /// Starts the Android Foreground Service via method channel
  Future<void> startForegroundBleService() async {
    final platform = MethodChannel("ble_service_channel");
    try {
      await platform.invokeMethod("startService");
    } catch (e) {
      print("Error starting BLE service: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Initializing BLE...",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // After BLE setup, load your normal UI
    return const FrameShell();  
    // Or use DevSettings first:
    // return const DevSettingsPage();
  }
}
