import 'package:flutter/material.dart';
import '../navigation/nav_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ✅ LOGOUT FUNCTION
  Future<void> _handleLogout(BuildContext context) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('Logout'),
        ),
      ],
    ),
  );

  if (shouldLogout != true) return;

  try {
    // Sign out
    await FirebaseAuth.instance.signOut();

    // ✅ FIX: Wait for auth state to update, then let AuthWrapper handle navigation
    if (context.mounted) {
      // Pop all routes and go back to root
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // Don't manually navigate - let AuthWrapper detect the logout
      // The StreamBuilder will automatically show LoginPage
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
        actions: [
          // ✅ LOGOUT BUTTON IN APP BAR
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          "Welcome to the Home Page",
          style: TextStyle(fontSize: 22),
        ),
      ),
      bottomNavigationBar: BottomNav(currentIndex: 0),
    );
  }
}