import 'package:finalsakay/pao_side/pages/pao_home.dart';
import 'package:finalsakay/pao_side/pages/pao_notifications_page.dart';
import 'package:finalsakay/pao_side/pages/pao_profile_page.dart';
import 'package:flutter/material.dart';

class PAOBotoomNav extends StatefulWidget {
  final int currentIndex;

  const PAOBotoomNav({super.key, required this.currentIndex});

  @override
  State<PAOBotoomNav> createState() => _PAOBotoomNavState();
}

class _PAOBotoomNavState extends State<PAOBotoomNav> {
  void _onTap(int index) {
    if (index == widget.currentIndex) return;

    Widget nextPage;

    switch (index) {
      case 0:
        nextPage = const PAOHomePage();
        break;
      case 1:
        nextPage = const PaoNotificationPage();
        break;
      case 2:
        nextPage = const PaoProfilePage();
        break;
      default:
        nextPage = const PAOHomePage();
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
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Notifs"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
