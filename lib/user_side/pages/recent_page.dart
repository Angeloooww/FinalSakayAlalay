import 'package:flutter/material.dart';
import '../navigation/nav_bar.dart';

class RecentPage extends StatelessWidget {
  const RecentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recent Activities"),
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          "Recent Activities Page",
          style: TextStyle(fontSize: 22),
        ),
      ),
      bottomNavigationBar: BottomNav(currentIndex: 1),
    );
  }
}