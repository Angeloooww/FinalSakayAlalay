import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_services.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const EditProfileScreen({
    super.key,
    required this.userData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _contactNumController;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.userData['firstName'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.userData['lastName'] ?? '',
    );
    _contactNumController = TextEditingController(
      text: widget.userData['contactNum'] ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactNumController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final currentUser = _firebaseService.getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Update only the name and contact number
      await _firebaseService.updateUserData(
        currentUser.uid,
        {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'contactNum': _contactNumController.text.trim(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Return true to indicate success, triggering a refresh in ProfileScreen
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Picture
                const Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFF2B5F9E),
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Email (Read-only)
                TextFormField(
                  initialValue: widget.userData['email'] ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                  ),
                  enabled: false,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                // First Name
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your first name';
                    }
                    if (value.trim().length < 2) {
                      return 'First name must be at least 2 characters';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your last name';
                    }
                    if (value.trim().length < 2) {
                      return 'Last name must be at least 2 characters';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // Contact Number
                TextFormField(
                  controller: _contactNumController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    hintText: '09123456789',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your contact number';
                    }
                    if (value.trim().length != 11) {
                      return 'Contact number must be 11 digits';
                    }
                    if (!value.startsWith('09')) {
                      return 'Contact number must start with 09';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Save Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5F9E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),

                // Cancel Button
                OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          Navigator.pop(context, false);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2B5F9E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF2B5F9E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}