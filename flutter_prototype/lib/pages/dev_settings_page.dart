import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ble_manager.dart';
import '../utils/ble_packet_test.dart';

class DevSettingsPage extends StatefulWidget {
  const DevSettingsPage({super.key});

  @override
  State<DevSettingsPage> createState() => _DevSettingsPageState();
}

class _DevSettingsPageState extends State<DevSettingsPage> {
  final ble = Get.find<BLEManager>();

  void _handleSwipe(DragEndDetails details) {
    // Calculate swipe velocity
    final velocity = details.velocity.pixelsPerSecond.dx;
    
    // Swipe right if velocity is positive and significant
    if (velocity > 300) {
      Get.to(() => const BLEPacketTestWidget());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: _handleSwipe,
      child: Scaffold(
        backgroundColor: const Color.fromRGBO(67, 67, 67, 1),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // ---- Title ----
              const Text(
                "BLUETOOTH",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // ---- Connection Status ----
              Obx(() {
                final connected = ble.isConnected.value;
                final addr = ble.connectedDeviceAddress.value;

                return Column(
                  children: [
                    Text(
                      connected ? "Connected" : "Disconnected",
                      style: TextStyle(
                        fontSize: 12,
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
                          fontSize: 10,
                          color: Colors.white60,
                        ),
                      )
                  ],
                );
              }),

              const SizedBox(height: 14),

              // ---- Buttons Row ----
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: Obx(() {
                        return ElevatedButton(
                          onPressed: () async {
                            if (!ble.gattReady.value) {
                              await ble.initGattServer();
                            }
                            if (!ble.isAdvertising.value) {
                              await ble.startAdvertising();
                            } else {
                              await ble.stopAdvertising();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: ble.isAdvertising.value
                                ? const Color.fromRGBO(153, 153, 153, 1)
                                : const Color.fromRGBO(142, 124, 195, 1),
                          ),
                          child: Text(
                            ble.isAdvertising.value ? "STOP" : "START",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ---- SEND TEST JSON ----
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () async {
                          await ble.sendJsonToPhone({
                            'message': '6767',
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor:
                              const Color.fromRGBO(142, 124, 195, 1),
                        ),
                        child: const Text(
                          "Send Test",
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ---- JSON Output Box ----
              Container(
                width: 120,
                height: 50, 
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(153, 153, 153, 1),
                  border: Border.all(color: Colors.black, width: 0.6),
                ),
                child: Obx(() {
                  final cmd = ble.lastReceivedCommand.value;
                  if (cmd == null) {
                    return const Center(
                      child: Text(
                        "No JSON received",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }

                  final pretty =
                      const JsonEncoder.withIndent('  ').convert(cmd);

                  return SingleChildScrollView(
                    child: Text(
                      pretty,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
