import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'upload.dart';
import 'services/firebase_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class UserDataScreen extends StatefulWidget {
  const UserDataScreen({super.key});

  @override
  State<UserDataScreen> createState() => _UserDataScreenState();
}

class _UserDataScreenState extends State<UserDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  String? _selectedDisability;

  final List<String> _disabilityTypes = [
    'Learning Disability',
    'Vision Impairment',
    'Intellectual Disability',
    'Orthopedic Disability',
    'Psychosocial Disability',
    'Chronic Illness',
    'Communication Disability',
    'Hearing Disability',
    'Other',
  ];

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDisability == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your disability type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    isRegistering = true;

    try {
      print('🔐 Creating Firebase Auth account...');

      // ✅ 1. CREATE FIREBASE AUTH USER
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final String userId = userCredential.user!.uid;
      print('✅ Firebase Auth UID: $userId');

      // ✅ 2. WAIT FOR AUTH TO FULLY PROPAGATE
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ 3. BUILD USER DATA
      final Map<String, dynamic> userData = {
        'firstName': firstNameController.text.trim(),
        'middleName': middleNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'contactNum': contactController.text.trim(),
        'email': emailController.text.trim(),
        'disabilityType': _selectedDisability,
        'userId': userId,
        'emailVerified': false,
        'accountStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // ✅ 4. USE BATCH WRITE FOR ATOMIC OPERATION
      final batch = FirebaseFirestore.instance.batch();
      
      // Reference to pwd_users document
      final pwdUserRef = FirebaseFirestore.instance
          .collection('pwd_users')
          .doc(userId);
      
      // Reference to users document
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);

      // Add both writes to batch
      batch.set(pwdUserRef, userData);
      batch.set(userRef, {
        'role': 'pwd',
        'email': emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ 5. COMMIT BATCH (ATOMIC OPERATION)
      print('💾 Saving user data with batch write...');
      await batch.commit();
      print('✅ User data saved successfully');

      // ✅ 6. FORCE AUTH REFRESH
      await FirebaseAuth.instance.currentUser?.reload();

      if (!mounted) return;

      // ✅ 7. SUCCESS MESSAGE
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // ✅ 8. WAIT A BIT BEFORE NAVIGATION
      await Future.delayed(const Duration(milliseconds: 300));

      // ✅ 9. GO TO UPLOAD SCREEN
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PwdCardUploadScreen(
            userId: userId,
            userData: userData,
          ),
        ),
      );
    }

    // ✅ HANDLE AUTH ERRORS
    on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuth error: ${e.code}');
      String message = 'Registration failed';

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered';
          break;
        case 'weak-password':
          message = 'Password must be at least 6 characters';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection';
          break;
        default:
          message = 'Registration failed: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    // ✅ HANDLE FIRESTORE PERMISSION ERRORS
    on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permission denied. Please check Firestore security rules.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        
        // Clean up the auth user since we couldn't create the profile
        try {
          await FirebaseAuth.instance.currentUser?.delete();
          print('🗑️ Cleaned up auth user due to permission error');
        } catch (deleteError) {
          print('⚠️ Could not delete auth user: $deleteError');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Database error: ${e.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }

    // ✅ HANDLE ANY OTHER ERRORS
    catch (e) {
      print('❌ Unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      isRegistering = false;
    }
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo
                        Image.asset(
                          'assets/images/removed.png',
                          width: 250,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 30),
                        
                        // Registration Form Container
                        Container(
                          constraints: const BoxConstraints(maxWidth: 500),
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
                          padding: const EdgeInsets.all(30),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                const Center(
                                  child: Text(
                                    'CREATE ACCOUNT',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2B5F9E),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 25),
                                
                                // Personal Information Section
                                _buildSectionTitle('PERSONAL INFORMATION'),
                                const SizedBox(height: 15),
                                
                                // First Name and Middle Name Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: firstNameController,
                                        label: 'FIRST NAME',
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: middleNameController,
                                        label: 'MIDDLE NAME',
                                        isRequired: false,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                
                                // Last Name
                                _buildTextFormField(
                                  controller: lastNameController,
                                  label: 'LAST NAME',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Last name is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                
                                // Contact Number
                                _buildTextFormField(
                                  controller: contactController,
                                  label: 'CONTACT NUMBER',
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Contact number is required';
                                    }
                                    if (value.length != 11) {
                                      return 'Must be 11 digits';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                
                                // Type of Disability Dropdown
                                _buildLabel('TYPE OF DISABILITY'),
                                const SizedBox(height: 5),
                                DropdownButtonFormField<String>(
                                  value: _selectedDisability,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2B5F9E),
                                        width: 1.2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2B5F9E),
                                        width: 1.2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                  hint: const Text(
                                    'Select disability type',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  isExpanded: true,
                                  menuMaxHeight: 250, // Limit dropdown height
                                  items: _disabilityTypes.map((String type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(
                                        type,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedDisability = newValue;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a disability type';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 25),
                                
                                // Account Information Section
                                _buildSectionTitle('ACCOUNT INFORMATION'),
                                const SizedBox(height: 15),
                                
                                // Email
                                _buildTextFormField(
                                  controller: emailController,
                                  label: 'EMAIL',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Email is required';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                        .hasMatch(value)) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                
                                // Password
                                _buildTextFormField(
                                  controller: passwordController,
                                  label: 'PASSWORD',
                                  isPassword: true,
                                  obscureText: _obscurePassword,
                                  onToggleVisibility: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password is required';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                
                                // Confirm Password
                                _buildTextFormField(
                                  controller: confirmPasswordController,
                                  label: 'CONFIRM PASSWORD',
                                  isPassword: true,
                                  obscureText: _obscureConfirmPassword,
                                  onToggleVisibility: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // Terms and Conditions Checkbox
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _agreeToTerms,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _agreeToTerms = value ?? false;
                                          });
                                        },
                                        activeColor: const Color(0xFF2B5F9E),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[700],
                                          ),
                                          children: const [
                                            TextSpan(text: 'I agree to the '),
                                            TextSpan(
                                              text: 'Terms and Conditions',
                                              style: TextStyle(
                                                color: Color(0xFF2B5F9E),
                                                fontWeight: FontWeight.w600,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 25),
                                
                                // Register Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleRegistration,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2B5F9E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      elevation: 2,
                                      disabledBackgroundColor: Colors.grey,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Text(
                                                'CREATE ACCOUNT',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward, size: 18),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // Login Link
                                Center(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      children: [
                                        const TextSpan(text: "already have an account? "),
                                        WidgetSpan(
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Login here',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF2B5F9E),
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
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2B5F9E),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF2B5F9E).withOpacity(0.7),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: isPassword && obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: Color(0xFF2B5F9E),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: Color(0xFF2B5F9E),
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                      size: 18,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            errorStyle: const TextStyle(fontSize: 10),
          ),
          validator: isRequired ? validator : null,
        ),
      ],
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    contactController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}