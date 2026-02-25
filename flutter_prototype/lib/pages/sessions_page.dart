import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'frame_page.dart';

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
              // Welcome message
              const Text(
                'Welcome Username',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 2),

              // Session 1 Button
              SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle session 1
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color.fromRGBO(153, 153, 153, 1),
                  ),
                  child: const Text(
                    "Session 1",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 3),

              // Session 2 Button
              SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle session 2
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color.fromRGBO(153, 153, 153, 1),
                  ),
                  child: const Text(
                    "Session 2",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 3),

              // Session 3 Button
              SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle session 3
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color.fromRGBO(153, 153, 153, 1),
                  ),
                  child: const Text(
                    "Session 3",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Horizontal divider
              const Divider(
                thickness: 1,
                color: Colors.grey,
              ),

              const SizedBox(height: 4),

              // New Session Button (same style as others but smaller/narrower)
              SizedBox(
                width: 80,
                height: 28,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to Frame page for new session
                    Get.to(() => const FrameShell());
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color.fromRGBO(153, 153, 153, 1),
                  ),
                  child: const Text(
                    "+ New",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
