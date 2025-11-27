import 'dart:async';
import 'package:flutter/material.dart';
import 'package:finalsakay/user_side/pages/home.dart';
import 'user_side/register.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_side/firebase_options.dart';
import 'user_side/services/firebase_services.dart';

void main() async {
  print('🔵 Starting app...');
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔵 Initializing Firebase...');
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,  // ADD THIS LINE
      );
      print('🔵 Firebase initialized successfully!');
    } else {
      print('🔵 Firebase already initialized');
    }
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }
  
  print('🔵 Running app...');
  runApp(SakayAlalayApp());
}



class SakayAlalayApp extends StatelessWidget {
  const SakayAlalayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SakayAlalay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    print('🟢 AuthWrapper building...');
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('🟢 Connection state: ${snapshot.connectionState}');
        print('🟢 Has data: ${snapshot.hasData}');
        
        if (snapshot.hasError) {
          print('❌ AuthWrapper error: ${snapshot.error}');
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('🟡 Waiting for auth state...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          print('✅ User logged in: ${snapshot.data!.email}');
          return HomePage();
        }

        print('✅ No user, showing login page');
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showErrorDialog("Email and password are required.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firebaseService.signInUser(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      _showErrorDialog("Login failed: ${e.toString()}");
    }

    setState(() => _isLoading = false);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 38, 114, 207),
                  Color.fromARGB(255, 152, 183, 218)
                ],
                stops: [0.0, 1.0],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo Image
                        Transform.translate(
                          offset: const Offset(0, -80),
                          child: Image.asset(
                            'assets/images/removed.png',
                            width: 300,
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Login Form Container
                        Transform.translate(
                          offset: const Offset(0, -70),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 380),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 32,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // LOGIN Title
                                const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B5F9E),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Email Field
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'EMAIL',
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),

                                // Password Field
                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'PASSWORD',
                                  isPassword: true,
                                ),
                                const SizedBox(height: 20),

                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2B5F9E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      elevation: 1,
                                      disabledBackgroundColor: Colors.grey,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              Text(
                                                'LOGIN',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Icon(Icons.arrow_forward,
                                                  size: 16),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Divider with "Or login with"
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(
                                          color: Colors.grey, thickness: 0.5),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0),
                                      child: Text(
                                        'Or login with',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(
                                          color: Colors.grey, thickness: 0.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Social Login Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildSocialButton(
                                      icon: Icons.apple,
                                      onTap: () {
                                        _showComingSoonDialog('Apple Sign-In');
                                      },
                                    ),
                                    const SizedBox(width: 16),
                                    _buildSocialButton(
                                      icon: Icons.g_mobiledata,
                                      onTap: () {
                                        _showComingSoonDialog('Google Sign-In');
                                      },
                                      isGoogle: true,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildSocialButton(
                                      icon: Icons.facebook,
                                      onTap: () {
                                        _showComingSoonDialog(
                                            'Facebook Sign-In');
                                      },
                                      isFacebook: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Register Link
                                Center(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      children: [
                                        const TextSpan(
                                            text: "don't have an account? "),
                                        WidgetSpan(
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const UserDataScreen(),
                                                ),
                                              );
                                            },
                                            child: const Text(
                                              'Register here',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF2B5F9E),
                                                fontWeight: FontWeight.w600,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$feature will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2B5F9E), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: const Color(0xFF2B5F9E).withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isGoogle = false,
    bool isFacebook = false,
  }) {
    Color backgroundColor = Colors.black;
    Color iconColor = Colors.white;

    if (isGoogle) {
      backgroundColor = Colors.white;
      iconColor = Colors.red;
    } else if (isFacebook) {
      backgroundColor = const Color(0xFF1877F2);
      iconColor = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isGoogle ? Colors.grey.shade300 : backgroundColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: isGoogle ? 36 : 24,
        ),
      ),
    );
  }
}