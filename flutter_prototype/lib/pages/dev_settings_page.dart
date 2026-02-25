import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ble_manager.dart';

class DevSettingsPage extends StatefulWidget {
  const DevSettingsPage({super.key});

  @override
  State<DevSettingsPage> createState() => _DevSettingsPageState();
}

class _DevSettingsPageState extends State<DevSettingsPage> {
  final ble = Get.find<BLEManager>();
  bool isDarkMode = true;

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

              // Start/Stop Advertising Button
              Center(
                child: SizedBox(
                  width: 150,
                  height: 28,
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
                        ble.isAdvertising.value ? "Stop Adv" : "Start Adv",
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 6),

              // Light/Dark Mode Button
              Center(
                child: SizedBox(
                  width: 150,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isDarkMode = !isDarkMode;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color.fromRGBO(142, 124, 195, 1),
                    ),
                    child: Text(
                      isDarkMode ? "Light Mode" : "Dark Mode",
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
                    onPressed: () {
                      // Handle logout
                      Get.snackbar('Logout', 'User logged out');
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
