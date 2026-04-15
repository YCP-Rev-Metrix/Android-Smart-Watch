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
  late final SessionController sessionController;

  @override
  void initState() {
    super.initState();
    sessionController = SessionController();
    
    // Check if already connected
    if (ble.isConnected.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.to(() => const SessionsPage());
      });
    }
    
    // Listen for BLE connection changes
    ever(ble.isConnected, (isConnected) {
      if (isConnected && mounted) {
        // Navigate to Sessions page on successful connection
        Get.to(() => const SessionsPage());
      }
    });
    
    // Listen for account packet reception
    ever(ble.lastAccountPacket, (packet) {
      if (packet != null && mounted) {
        print('HomePage: Received account packet, initializing session');
        sessionController.initializeFromPacket(
          sessionId: packet.sessionId,
          gameNumber: packet.gameNumber ?? 1,
          frameNumber: packet.frameNumber ?? 1,
          shotNumber: packet.shotNumber ?? 1,
          balls: packet.balls,
          gameCount: packet.gameCount,
          gameStates: packet.gameStates,
        );
        // Navigate to Sessions page only if not syncing
        if (!ble.isSyncing.value) {
          Get.to(() => const SessionsPage());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(18, 26, 36, 1),
      appBar: AppBar(
        title: const Text('Home', style: TextStyle(fontSize: 14)),
        toolbarHeight: 40,
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(18, 26, 36, 1),
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
                  backgroundColor: const Color.fromRGBO(250, 136, 71, 1),
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
