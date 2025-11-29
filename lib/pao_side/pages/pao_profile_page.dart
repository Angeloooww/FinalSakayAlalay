import 'package:finalsakay/pao_side/navigation/pao_nav_bar.dart';
import 'package:flutter/material.dart';

class PaoProfilePage extends StatelessWidget {
  const PaoProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recent Activities")),

      body: const Center(
        child: Text(
          "PAO Profile Page",
          style: TextStyle(fontSize: 22),
        ),
      ),
      bottomNavigationBar: PAOBotoomNav(currentIndex: 1),
    );
  }
}