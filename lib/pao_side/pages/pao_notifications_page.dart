import 'package:flutter/material.dart';
import 'package:finalsakay/pao_side/navigation/pao_nav_bar.dart';

class PaoNotificationPage extends StatelessWidget {
  const PaoNotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _notificationCard(
            title: "New Assistance Request",
            message: "A user needs help near Jaro Plaza. Tap to view details.",
            time: "2 mins ago",
            icon: Icons.warning_rounded,
          ),
          _notificationCard(
            title: "Request Accepted",
            message: "You accepted the request from Maria Santos.",
            time: "30 mins ago",
            icon: Icons.check_circle,
          ),
          _notificationCard(
            title: "Trip Completed",
            message: "Your assistance for Carlo Dizon is marked completed.",
            time: "1 hour ago",
            icon: Icons.flag_rounded,
          ),
          _notificationCard(
            title: "User Cancelled Request",
            message: "Angelo cancelled his request before pickup.",
            time: "3 hours ago",
            icon: Icons.cancel,
          ),
        ],
      ),

      bottomNavigationBar: PAOBotoomNav(currentIndex: 1),
    );
  }

  // Notification card widget
  Widget _notificationCard({
    required String title,
    required String message,
    required String time,
    required IconData icon,
  }) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: () {
          // You can open details page here later
        },
        borderRadius: BorderRadius.circular(14),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      message,
                      style: const TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 14,
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
