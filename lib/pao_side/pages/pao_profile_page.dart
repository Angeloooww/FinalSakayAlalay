import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finalsakay/pao_side/navigation/pao_nav_bar.dart';
import '../../user_side/services/firebase_services.dart';
import 'package:finalsakay/main.dart';

class PaoProfilePage extends StatefulWidget {
  const PaoProfilePage({super.key});

  @override
  State<PaoProfilePage> createState() => _PaoProfilePageState();
}

class _PaoProfilePageState extends State<PaoProfilePage> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic>? paoData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPaoData();
  }

  Future<void> _loadPaoData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        setState(() {
          errorMessage = 'No PAO logged in';
          isLoading = false;
        });
        return;
      }

      // ✅ Load PAO data from "pao" collection
      final data = await _firebaseService.getPaoUserData(currentUser.uid);

      setState(() {
        paoData = data;
        isLoading = false;
      });

    } catch (e) {
      setState(() {
        errorMessage = 'Error loading PAO profile: $e';
        isLoading = false;
      });
    }
  }

  // ✅ Logout Logic (Same Fix Applied)
  Future<void> _handleLogout() async {
    try {
      final shouldLogout = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          );
        },
      );

      if (shouldLogout != true) return;

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.popUntil((route) => false);
        navigator.push(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PAO Settings'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadPaoData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : paoData == null
                  ? const Center(child: Text('No PAO data found'))
                  : RefreshIndicator(
                      onRefresh: _loadPaoData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // ✅ Profile Picture
                              const CircleAvatar(
                                radius: 50,
                                backgroundColor: Color(0xFF2B5F9E),
                                child: Icon(Icons.person, size: 60, color: Colors.white),
                              ),

                              const SizedBox(height: 16),

                              // ✅ PAO Name
                              Text(
                                '${paoData!['firstName']} ${paoData!['lastName']}'.trim(),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 8),

                              // ✅ Email
                              Text(
                                paoData!['email'] ?? 'No email',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),

                              const SizedBox(height: 24),

                              // ✅ Edit Profile Button
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2B5F9E),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Edit Profile'),
                              ),

                              const SizedBox(height: 32),

                              // ✅ Menu Items
                              _buildMenuItem(
                                icon: Icons.route,
                                title: 'Assigned Routes',
                                onTap: () {},
                              ),
                              _buildMenuItem(
                                icon: Icons.notifications,
                                title: 'Notifications',
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
                                title: 'PAO Location',
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

                              // ✅ LOGOUT
                              _buildMenuItem(
                                icon: Icons.logout,
                                title: 'Logout',
                                onTap: _handleLogout,
                                isDestructive: true,
                              ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),

      bottomNavigationBar: PAOBotoomNav(currentIndex: 2),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.grey[700]),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : null)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
