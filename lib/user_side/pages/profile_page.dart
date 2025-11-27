import 'package:flutter/material.dart';
import '../services/firebase_services.dart';
import '../navigation/nav_bar.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Profile'),
        centerTitle: true,
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
                                '${userData!['firstName']} ${userData!['middleName'] ?? ''} ${userData!['lastName']}'.trim(),
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
                              _buildMenuItem(
                                icon: Icons.logout,
                                title: 'Logout',
                                onTap: () async {
                                  await _firebaseService.signOut();
                                  if (mounted) {
                                    Navigator.of(context).pushReplacementNamed('/login');
                                  }
                                },
                              ),
                              const SizedBox(height: 32),
                              
                              // User Info Card
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Personal Information',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildInfoRow('Contact Number', userData!['contactNum'] ?? 'N/A'),
                                      _buildInfoRow('Disability Type', userData!['disabilityType'] ?? 'N/A'),
                                      _buildInfoRow('User ID', userData!['userId'] ?? 'N/A'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
      bottomNavigationBar: BottomNav(currentIndex: 4), // Assuming profile is at index 4
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}