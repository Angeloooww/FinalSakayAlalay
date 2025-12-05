import 'package:flutter/material.dart';
import '../navigation/nav_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

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
              "Notifications",
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

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _notifCard(
            title: "PAO is on the way",
            message: "Your assigned PAO, John Cruz, is heading to your location.",
            time: "2 mins ago",
            icon: Icons.directions_walk_rounded,
          ),

          _notifCard(
            title: "Request Accepted",
            message: "A PAO accepted your request at Jaro Plaza.",
            time: "10 mins ago",
            icon: Icons.check_circle_rounded,
          ),

          _notifCard(
            title: "Trip Completed",
            message: "Your assistance request has been marked as completed.",
            time: "1 hour ago",
            icon: Icons.flag_rounded,
          ),

          _notifCard(
            title: "PAO Cancelled",
            message: "The PAO cancelled due to emergency. Please request again.",
            time: "3 hours ago",
            icon: Icons.cancel_rounded,
          ),
        ],
      ),

      bottomNavigationBar: BottomNav(currentIndex: 2),
    );
  }

  // USER NOTIF CARD WIDGET
  Widget _notifCard({
    required String title,
    required String message,
    required String time,
    required IconData icon,
  }) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // Open notif details later
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: Color(0xFF2B5F9E)),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      message,
                      style: GoogleFonts.lato(
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      time,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
