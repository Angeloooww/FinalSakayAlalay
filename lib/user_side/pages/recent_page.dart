import 'package:flutter/material.dart';
import '../navigation/nav_bar.dart';

class RecentPage extends StatelessWidget {
  const RecentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recent Activities")),

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
