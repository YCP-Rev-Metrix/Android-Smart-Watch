import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'frame_page.dart';
import '../controllers/ble_manager.dart';
import '../controllers/session_controller.dart';
import '../models/account_packet.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
      appBar: AppBar(
        title: const Text('Sessions', style: TextStyle(fontSize: 14)),
        toolbarHeight: 40,
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Welcome message - dynamic username from BLE
              Obx(() {
                final username = Get.find<BLEManager>().lastAccountPacket.value?.username ?? 'Guest';
                return Text(
                  'Welcome $username',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                );
              }),

              const SizedBox(height: 15),

              // Event name button (only shown when account packet available)
              Obx(() {
                final packet = Get.find<BLEManager>().lastAccountPacket.value;
                if (packet == null) return const SizedBox.shrink();
                return Center(
                  child: _sessionButton(
                    label: packet.eventName.isEmpty ? 'Event Session' : packet.eventName,
                    onPressed: () => _startEventSession(packet),
                  ),
                );
              }),

              const SizedBox(height: 10),

              // Anonymous session button (always shown)
              Center(
                child: _sessionButton(
                  label: 'Anonymous',
                  onPressed: _startAnonymousSession,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: 150,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color.fromRGBO(153, 153, 153, 1),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _startEventSession(AccountPacket packet) {
    final gameNum = (packet.gameNumber == null || packet.gameNumber == 0) ? 1 : packet.gameNumber!;
    final frameNum = (packet.frameNumber == null || packet.frameNumber == 0) ? 1 : packet.frameNumber!;
    final shotNum = (packet.shotNumber == null || packet.shotNumber == 0) ? 1 : packet.shotNumber!;
    SessionController().initializeFromPacket(
      sessionId: packet.sessionId,
      gameNumber: gameNum,
      frameNumber: frameNum,
      shotNumber: shotNum,
      balls: packet.balls,
    );
    Get.to(() => const FrameShell());
  }

  void _startAnonymousSession() {
    SessionController().initializeAnonymous();
    Get.to(() => const FrameShell());
  }
}
