import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ble_manager.dart';
import '../controllers/session_controller.dart';
import 'sessions_page.dart';

class DevSettingsPage extends StatefulWidget {
  const DevSettingsPage({super.key});

  @override
  State<DevSettingsPage> createState() => _DevSettingsPageState();
}

class _DevSettingsPageState extends State<DevSettingsPage> {
  final ble = Get.find<BLEManager>();
  bool isSyncing = false;
  bool isEnding = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontSize: 14)),
        backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
        toolbarHeight: 40,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Connection Status
              Obx(() {
                final connected = ble.isConnected.value;
                final addr = ble.connectedDeviceAddress.value;

                return Column(
                  children: [
                    Text(
                      connected ? "Connected" : "Disconnected",
                      style: TextStyle(
                        fontSize: 11,
                        color: connected
                            ? const Color.fromRGBO(142, 124, 195, 1)
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (connected && addr.isNotEmpty)
                      Text(
                        addr,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white60,
                        ),
                      )
                  ],
                );
              }),

              const SizedBox(height: 8),

              // Sync Session Button
              Center(
                child: SizedBox(
                  width: 150,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: isSyncing
                        ? null
                        : () async {
                            setState(() {
                              isSyncing = true;
                            });
                            try {
                              ble.isSyncing.value = true;
                              await ble.sendSyncCommand();
                              print('WATCH: Sync command sent to phone');
                              
                              // Wait for packet arrival
                              await Future.delayed(const Duration(seconds: 3));
                            } catch (e) {
                              print('WATCH: Failed to send sync: $e');
                            } finally {
                              ble.isSyncing.value = false;
                              if (mounted) {
                                setState(() {
                                  isSyncing = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: isSyncing
                          ? const Color.fromRGBO(100, 100, 100, 1)
                          : const Color.fromRGBO(142, 124, 195, 1),
                    ),
                    child: Text(
                      isSyncing ? "Syncing..." : "Sync",
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // End Session Button
              Center(
                child: SizedBox(
                  width: 150,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: isEnding
                        ? null
                        : () async {
                            setState(() {
                              isEnding = true;
                            });
                            try {
                              final sessionId = ble.lastAccountPacket.value?.sessionId;
                              if (sessionId == null) {
                                print('WATCH: No session ID available');
                                return;
                              }
                              
                              await ble.sendNextSessionCommand(sessionId);
                              print('WATCH: Next session command sent with sessionId: $sessionId');
                              
                              // Navigate to sessions page
                              if (mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (context) => const SessionsPage()),
                                );
                              }
                            } catch (e) {
                              print('WATCH: Failed to end session: $e');
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isEnding = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: isEnding
                          ? const Color.fromRGBO(100, 100, 100, 1)
                          : const Color.fromRGBO(255, 165, 0, 1),
                    ),
                    child: Text(
                      isEnding ? "Ending..." : "End",
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Log Out Button
              Center(
                child: SizedBox(
                  width: 150,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Send disconnect command to phone
                      if (ble.isConnected.value) {
                        await ble.sendDisconnectCommand();
                        // Give the phone a moment to receive the command
                        await Future.delayed(const Duration(milliseconds: 500));
                      }
                      
                      // Disconnect the current connection
                      await ble.disconnectCurrentConnection();
                      
                      // Clear the session
                      final sessionController = SessionController();
                      sessionController.currentSession = null;
                      
                      // Return to home page
                      if (mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      "Log Out",
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Exit Button
              Center(
                child: SizedBox(
                  width: 100,
                  height: 22,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color.fromRGBO(100, 100, 100, 1),
                    ),
                    child: const Text(
                      "Exit",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
