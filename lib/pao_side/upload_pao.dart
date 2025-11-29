import 'dart:io';
import 'dart:typed_data';
import 'package:finalsakay/pao_side/pages/pao_home.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../user_side/services/firebase_services.dart';
import '../main.dart';

class PaoIdUploadScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const PaoIdUploadScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<PaoIdUploadScreen> createState() => _PaoIdUploadScreenState();
}

class _PaoIdUploadScreenState extends State<PaoIdUploadScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  Uint8List? _webImage; 
  XFile? _pickedFile;
  bool _isUploading = false;
  bool _uploadComplete = false;
  double _uploadProgress = 0.0;

  // Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );

      if (pickedFile != null) {
        _pickedFile = pickedFile;
        
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImage = bytes;
            _uploadComplete = false;
          });
        } else {
          setState(() {
            _selectedImage = File(pickedFile.path);
            _uploadComplete = false;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting image: ${e.toString()}');
    }
  }

  // Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile != null) {
        _pickedFile = pickedFile;
        
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImage = bytes;
            _uploadComplete = false;
          });
        } else {
          setState(() {
            _selectedImage = File(pickedFile.path);
            _uploadComplete = false;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error taking photo: ${e.toString()}');
    }
  }

  // Show image source selection bottom sheet
  Future<void> _showImageSourceSelection() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F9E),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF2B5F9E),
                    size: 30,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                if (!kIsWeb)
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF2B5F9E),
                      size: 30,
                    ),
                    title: const Text('Take a Photo'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromCamera();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Upload PAO ID to Firestore as Base64
  Future<void> _uploadPaoId() async {
    if (_selectedImage == null && _webImage == null) {
      _showErrorSnackBar('Please select an image first');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      print('🚀 Starting PAO ID upload...');
      print('User ID: ${widget.userId}');
      print('Platform: ${kIsWeb ? "Web" : "Mobile"}');
      
      // Simulate upload progress
      for (int i = 0; i <= 50; i += 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          setState(() {
            _uploadProgress = i / 100;
          });
        }
      }

      if (kIsWeb) {
        print('📤 Uploading PAO ID from Web...');
        await _firebaseService.uploadPaoIdBase64Web(
          _webImage!,
          widget.userId,
        );
      } else {
        print('📤 Uploading PAO ID from Mobile...');
        await _firebaseService.uploadPaoIdBase64(
          _selectedImage!,
          widget.userId,
        );
      }

      print('✅ PAO ID upload completed successfully!');

      if (mounted) {
        setState(() {
          _uploadProgress = 1.0;
          _uploadComplete = true;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PAO ID uploaded successfully!.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          // Sign out the user
          await FirebaseAuth.instance.signOut();
          
          // Navigate back to login page
          Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(
    builder: (context) => const PAOHomePage(), // Import from main.dart
  ),
  (route) => false,
);
        }
      }

    } catch (e) {
      print('❌ PAO ID upload failed: $e');
      if (mounted) {
        _showErrorSnackBar('Upload failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Skip upload (optional)
  void _skipUpload() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Upload?'),
        content: const Text(
          'You can upload your PAO ID later from your profile settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/pao_login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5F9E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Skip for Now'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 38, 114, 207),
              Color.fromARGB(255, 152, 183, 218)
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Image.asset(
                      'assets/images/removed.png',
                      width: 200,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(height: 100);
                      },
                    ),
                    const SizedBox(height: 30),

                    // Main Card Container
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
                      child: Column(
                        children: [
                          // Title
                          const Text(
                            'UPLOAD PAO ID',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B5F9E),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          
                          // Subtitle
                          Text(
                            'Please upload a clear photo of your PAO ID card',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Image Preview or Placeholder
                          GestureDetector(
                            onTap: _isUploading ? null : _showImageSourceSelection,
                            child: Container(
                              width: double.infinity,
                              height: 250,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (_selectedImage != null || _webImage != null)
                                      ? const Color(0xFF2B5F9E)
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: _buildImagePreview(),
                            ),
                          ),
                          
                          const SizedBox(height: 20),

                          // Change Image Button
                          if ((_selectedImage != null || _webImage != null) && !_isUploading)
                            TextButton.icon(
                              onPressed: _showImageSourceSelection,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Change Image'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2B5F9E),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Upload Progress
                          if (_isUploading)
                            Column(
                              children: [
                                LinearProgressIndicator(
                                  value: _uploadProgress,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2B5F9E),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Uploading... ${(_uploadProgress * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),

                          // Upload Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isUploading || _uploadComplete
                                  ? null
                                  : _uploadPaoId,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2B5F9E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: _isUploading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : _uploadComplete
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check_circle, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'UPLOAD COMPLETE',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'UPLOAD PAO ID',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.upload_file, size: 18),
                                          ],
                                        ),
                            ),
                          ),
                          
                          const SizedBox(height: 15),

                          // Skip Button
                          TextButton(
                            onPressed: _isUploading ? null : _skipUpload,
                            child: Text(
                              'Skip for now',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build image preview
  Widget _buildImagePreview() {
    if (kIsWeb && _webImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          _webImage!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 50, color: Colors.red[300]),
                  const SizedBox(height: 10),
                  Text(
                    'Error loading image',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 50, color: Colors.red[300]),
                  const SizedBox(height: 10),
                  Text(
                    'Error loading image',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to select image',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      );
    }
  }
}