import 'package:flutter/material.dart';
import '../navigation/nav_bar.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
      ),

      body: const Center(
        child: Text(
          "Notifications Page",
          style: TextStyle(fontSize: 22),
        ),
      ),

      bottomNavigationBar: BottomNav(currentIndex: 3),
    );
  }
}