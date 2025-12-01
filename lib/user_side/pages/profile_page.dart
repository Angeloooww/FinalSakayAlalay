import 'package:flutter/material.dart';
import '../services/firebase_services.dart';
import '../navigation/nav_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finalsakay/main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get current user
      final currentUser = _firebaseService.getCurrentUser();
      
      if (currentUser == null) {
        setState(() {
          errorMessage = 'No user logged in';
          isLoading = false;
        });
        return;
      }

      // Fetch user data from Firestore
      final data = await _firebaseService.getUserData(currentUser.uid);
      
      setState(() {
        userData = data;
        isLoading = false;
      });

    } catch (e) {
      setState(() {
        errorMessage = 'Error loading profile: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
  print('🔴 _handleLogout called');
  
  try {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        print('🔴 Dialog building');
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                print('🔴 Cancel pressed');
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                print('🔴 Logout confirmed');
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    print('🔴 Dialog result: $shouldLogout');

    if (shouldLogout != true) {
      print('🔴 Logout cancelled');
      return;
    }

    print('🔴 Signing out...');
    await FirebaseAuth.instance.signOut();
    print('🔴 Signed out successfully');

    // ✅ NEW FIX: Force complete navigation reset
    if (mounted) {
      print('🔴 Forcing navigation reset...');
      
      // Get the navigator
      final navigator = Navigator.of(context);
      
      // Remove ALL routes
      navigator.popUntil((route) => false);
      
      // Push LoginPage as the new root
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      
      print('🔴 Navigation complete');
    }
  } catch (e, stackTrace) {
    print('🔴 Error during logout: $e');
    print('🔴 Stack trace: $stackTrace');
    if (mounted) {
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
        title: const Text('My Profile'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : userData == null
                  ? const Center(child: Text('No user data found'))
                  : RefreshIndicator(
                      onRefresh: _loadUserData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Profile Picture
                              const CircleAvatar(
                                radius: 50,
                                backgroundColor: Color(0xFF2B5F9E),
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // User Name
                              Text(
                                'Hello, ${userData!['firstName']} ${userData!['lastName']}!'.trim(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              
                              // Email
                              Text(
                                userData!['email'] ?? 'No email',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Edit Profile Button
                              ElevatedButton(
                                onPressed: () {
                                  // Navigate to edit profile
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2B5F9E),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Edit Profile'),
                              ),
                              const SizedBox(height: 32),
                              
                              // Menu Items
                              _buildMenuItem(
                                icon: Icons.favorite_border,
                                title: 'Favorites',
                                onTap: () {},
                              ),
                              _buildMenuItem(
                                icon: Icons.route,
                                title: 'Routes',
                                onTap: () {},
                              ),
                              const Divider(height: 32),
                              _buildMenuItem(
                                icon: Icons.language,
                                title: 'Language',
                                onTap: () {},
                              ),
                              _buildMenuItem(
                                icon: Icons.location_on_outlined,
                                title: 'Location',
                                onTap: () {},
                              ),
                              _buildMenuItem(
                                icon: Icons.subscriptions_outlined,
                                title: 'Subscription',
                                onTap: () {},
                              ),
                              const Divider(height: 32),
                              _buildMenuItem(
                                icon: Icons.cleaning_services_outlined,
                                title: 'Clear cache',
                                onTap: () {},
                              ),
                              _buildMenuItem(
                                icon: Icons.history,
                                title: 'Clear history',
                                onTap: () {},
                              ),
                              // ✅ FIXED LOGOUT BUTTON
                              _buildMenuItem(
                                icon: Icons.logout,
                                title: 'Logout',
                                onTap: () {
                                  print('🔴 Logout button tapped!');
                                  _handleLogout();
                                },
                                isDestructive: true,
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
      bottomNavigationBar: BottomNav(currentIndex: 4),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon, 
        color: isDestructive ? Colors.red : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}