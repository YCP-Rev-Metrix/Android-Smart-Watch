import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ble_manager.dart';
import '../controllers/session_controller.dart';
import 'frame_page.dart';
import 'sessions_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ble = Get.find<BLEManager>();

  @override
  void initState() {
    super.initState();
    // Listen for BLE connection
    ever(ble.isConnected, (isConnected) {
      if (isConnected) {
        // Navigate to Sessions page on successful connection
        Get.to(() => const SessionsPage());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
      appBar: AppBar(
        title: const Text('Home', style: TextStyle(fontSize: 14)),
        toolbarHeight: 40,
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Waiting to pair text
            const Text(
              'Waiting to pair...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            
            // Advertising status text
            Obx(() {
              return Text(
                ble.isAdvertising.value ? 'Advertise successful' : 'Advertising unsuccessful',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: ble.isAdvertising.value ? Colors.green : Colors.red,
                ),
              );
            }),
            const SizedBox(height: 16),
            
            // Horizontal divider
            const Divider(
              thickness: 1,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            
            // Offline Mode button
            SizedBox(
              width: 100,
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  // Initialize anonymous session (zero everything out for testing)
                  SessionController().initializeAnonymous();
                  // Navigate to Frame page for offline mode
                  Get.to(() => const FrameShell());
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color.fromRGBO(142, 124, 195, 1),
                ),
                child: const Text(
                  'Offline Mode',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
