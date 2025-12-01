import 'package:flutter/material.dart';
import '../navigation/nav_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_page.dart';

class RecentPage extends StatelessWidget {
  const RecentPage({super.key});

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Image.asset(
                'assets/images/removed.png',
                height: 40,
                width: 40,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Recent Activities",
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            tooltip: "Settings",
          ),
        ],
      ),
      // ... rest of your body content
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