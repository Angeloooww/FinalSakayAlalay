import 'dart:async';
import 'package:flutter/material.dart';
import 'package:finalsakay/user_side/pages/home.dart';
import 'package:finalsakay/pao_side/pao_home.dart';
import 'user_side/register.dart';
import 'pao_side/register_pao.dart';
import 'pao_side/upload_pao.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_side/firebase_options.dart';
import 'user_side/services/firebase_services.dart';
// import 'user_side/upload.dart';
// import 'pao_side/upload_pao.dart';

bool isRegistering = false;

void main() async {
  print('🔵 Starting app...');
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔵 Initializing Firebase...');
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('🔵 Firebase initialized successfully!');
    } else {
      print('🔵 Firebase already initialized');
    }
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }
  
  print('🔵 Running app...');
  runApp(const SakayAlalayApp());
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
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/user_register': (context) => const UserDataScreen(),
        '/pao_register': (context) => const PAORegistrationScreen(),
        '/home': (context) => HomePage(),
        '/pao_home': (context) => PAOHomePage(),
      },
      onUnknownRoute: (settings) {
        print('⚠️ Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => const LoginPage(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Map<String, dynamic>> _getUserData(String uid) async {
    try {
      print('🔍 Fetching user data for UID: $uid');
      
      // First, get the role from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (!userDoc.exists) {
        print('⚠️ User document does not exist in users collection');
        return {'role': null, 'hasData': false};
      }

      final role = userDoc.data()?['role'] as String?;
      print('✅ User role found: $role');

      if (role == null) {
        print('⚠️ Role is null');
        return {'role': null, 'hasData': false};
      }

      // Now fetch full data from the appropriate collection
      DocumentSnapshot fullDataDoc;
      String collectionName;
      
      if (role == 'pwd') {
        collectionName = 'pwd_users';
        print('🔍 Checking pwd_users collection...');
        fullDataDoc = await FirebaseFirestore.instance
            .collection('pwd_users')
            .doc(uid)
            .get();
      } else if (role == 'pao') {
        collectionName = 'pao';
        print('🔍 Checking pao collection...');
        fullDataDoc = await FirebaseFirestore.instance
            .collection('pao')
            .doc(uid)
            .get();
      } else {
        print('⚠️ Unknown role: $role');
        return {'role': role, 'hasData': false};
      }

      print('🔍 Collection: $collectionName, Document exists: ${fullDataDoc.exists}');

      if (!fullDataDoc.exists) {
        print('⚠️ Full user data not found in $collectionName collection');
        return {'role': role, 'hasData': false};
      }

      final fullData = fullDataDoc.data() as Map<String, dynamic>?;
      print('✅ Full user data found');
      print('📋 User data keys: ${fullData?.keys.toList()}');
      
      // Check if user has uploaded their ID
      final idFieldName = role == 'pwd' ? 'pwdCardBase64' : 'paoIdBase64';
      final idValue = fullData?[idFieldName];
      final hasUploadedId = idValue != null && idValue.toString().isNotEmpty;
      
      print('🔍 Checking for $idFieldName...');
      print('✅ Has uploaded ID: $hasUploadedId');
      if (!hasUploadedId) {
        print('⚠️ ID field is missing or empty');
      }

      return {
        'role': role,
        'hasData': true,
        'hasUploadedId': hasUploadedId,
        'data': fullData,
      };
      
    } catch (e, stackTrace) {
      print('❌ Error fetching user data: $e');
      print('❌ Stack trace: $stackTrace');
      return {'role': null, 'hasData': false, 'error': e.toString()};
    }
  }

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('🟡 Waiting for auth state...');
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // If a registration is in progress, show a simple loading UI
        if (isRegistering) {
          print('🟡 Registration in progress — AuthWrapper paused');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          print('✅ User logged in: ${user.email}');
          print('✅ Email verified: ${user.emailVerified}');
          
          // Fetch user data and check if profile is complete
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(user.uid),
            builder: (context, dataSnapshot) {
              if (dataSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Verifying account...'),
                      ],
                    ),
                  ),
                );
              }

              final userData = dataSnapshot.data ?? {};
              final role = userData['role'];
              final hasData = userData['hasData'] == true;
              final hasUploadedId = userData['hasUploadedId'] == true;

              print('✅ User role: $role');
              print('✅ Has data: $hasData');
              print('✅ Has uploaded ID: $hasUploadedId');

              // If user doesn't have complete data, and we are NOT registering, sign them out and send to login
              if (!hasData || !hasUploadedId) {
                print('⚠️ Incomplete profile detected');
                // If registration is ongoing, just show a loading screen (handled earlier).
                // If not registering, sign out and prompt to login/register.
                if (!isRegistering) {
                  print('⚠️ Signing out because profile is incomplete and not registering');
                  // Don't await, let it happen in background
                  FirebaseAuth.instance.signOut();
                  
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, 
                            size: 60, 
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Profile Incomplete',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Please complete your registration and upload your ID.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text('Go to Login'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // Shouldn't reach this because we return earlier when isRegistering is true,
                  // but be defensive: show loading spinner.
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
              }

              // Navigate based on role
              if (role == 'pao') {
                print('🔄 Redirecting to PAO Home');
                return PAOHomePage();
              } else if (role == 'pwd') {
                print('🔄 Redirecting to PWD User Home');
                return HomePage();
              } else {
                // Unknown role
                print('⚠️ Unknown role: $role');
                if (!isRegistering) {
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                } else {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
              }
            },
          );
        }

        print('✅ No user, showing login page');
        return const LoginPage();
      },
    );
  }
}

/* ----------------------- LOGIN PAGE (unchanged) ----------------------- */

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
  String _selectedRole = 'pwd'; // Changed default to 'pwd' to match collection name

  // Color getter based on selected role
  Color get _primaryColor => _selectedRole == 'pwd' 
      ? const Color(0xFF2B5F9E)  // Blue for User
      : const Color(0xFF0D47A1);  // Dark Blue for PAO

  Color get _gradientTopColor => _selectedRole == 'pwd'
      ? const Color.fromARGB(255, 38, 114, 207)   // Blue gradient
      : const Color.fromARGB(255, 13, 71, 161);   // Dark Blue gradient

  Color get _gradientBottomColor => _selectedRole == 'pwd'
      ? const Color.fromARGB(255, 152, 183, 218)  // Light blue
      : const Color.fromARGB(255, 25, 118, 210);  // Medium Blue

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showErrorDialog("Email and password are required.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🔐 Attempting login for: ${_emailController.text.trim()}');
      print('🔐 Selected role: $_selectedRole');
      
      // Sign in the user
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('✅ Authentication successful');

      // Verify the user's role matches the selected role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        print('❌ User document not found');
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          _showErrorDialog('Account not found. Please register first.');
        }
        return;
      }

      final actualRole = userDoc.data()?['role'];
      print('✅ User actual role: $actualRole');

      if (actualRole != _selectedRole) {
        // Role mismatch - sign out and show error
        print('❌ Role mismatch! Expected: $_selectedRole, Got: $actualRole');
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          _showErrorDialog(
            "Invalid credentials for ${_selectedRole == 'pao' ? 'PAO' : 'User'} login. "
            "Please check your account type or use the correct login option."
          );
        }
      } else {
        print('✅ Role matches, AuthWrapper will handle navigation');
        // AuthWrapper will automatically handle navigation
        // Just wait a moment for the stream to update
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuth error: ${e.code} - ${e.message}');
      String errorMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password. Please try again.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      
      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      if (mounted) {
        _showErrorDialog("Login failed: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
            child: Text(
              'OK',
              style: TextStyle(color: _primaryColor),
            ),
          )
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
            child: Text(
              'OK',
              style: TextStyle(color: _primaryColor),
            ),
          ),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _gradientTopColor,
                  _gradientBottomColor,
                ],
                stops: const [0.0, 1.0],
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
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 300,
                                height: 180,
                                color: Colors.white.withOpacity(0.2),
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
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
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryColor,
                                    letterSpacing: 1.2,
                                  ),
                                  child: const Text('LOGIN'),
                                ),
                                const SizedBox(height: 20),

                                // Role Selector
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _primaryColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _selectedRole = 'pwd'),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: _selectedRole == 'pwd'
                                                  ? _primaryColor
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'USER',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _selectedRole == 'pwd'
                                                    ? Colors.white
                                                    : Colors.grey[700],
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _selectedRole = 'pao'),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: _selectedRole == 'pao'
                                                  ? _primaryColor
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'PAO',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _selectedRole == 'pao'
                                                    ? Colors.white
                                                    : Colors.grey[700],
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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
                                      backgroundColor: _primaryColor,
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
                                                  AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'LOGIN',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Icon(Icons.arrow_forward, size: 16),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Divider with "Or login with"
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(color: Colors.grey, thickness: 0.5),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Text(
                                        'Or login with',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(color: Colors.grey, thickness: 0.5),
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
                                        _showComingSoonDialog('Facebook Sign-In');
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
                                        const TextSpan(text: "don't have an account? "),
                                        WidgetSpan(
                                          child: GestureDetector(
                                            onTap: () {
                                              if (_selectedRole == 'pwd') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const UserDataScreen(),
                                                  ),
                                                );
                                              } else {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const PAORegistrationScreen(),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Text(
                                              'Register here',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _primaryColor,
                                                fontWeight: FontWeight.w600,
                                                decoration: TextDecoration.underline,
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
        border: Border.all(color: _primaryColor, width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: _primaryColor.withOpacity(0.7),
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
