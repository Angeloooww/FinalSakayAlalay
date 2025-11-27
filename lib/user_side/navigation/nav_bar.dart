import 'package:flutter/material.dart';
import '../pages/home.dart';
import '../pages/recent_page.dart';
import '../pages/maps_page.dart';
import '../pages/notification_page.dart';
import '../pages/profile_page.dart';

class BottomNav extends StatefulWidget {
  final int currentIndex;

  const BottomNav({super.key, required this.currentIndex});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  void _onTap(int index) {
    if (index == widget.currentIndex) return;

    Widget nextPage;

    switch (index) {
      case 0:
        nextPage = const HomePage();
        break;
      case 1:
        nextPage = const RecentPage();
        break;
      case 2:
        nextPage = const MapsPage();
        break;
      case 3:
        nextPage = const NotificationsPage();
        break;
      case 4:
        nextPage = const ProfileScreen();
        break;
      default:
        nextPage = const HomePage();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: widget.currentIndex,
      onTap: _onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "Recent"),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: "Maps"),
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Notifs"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
