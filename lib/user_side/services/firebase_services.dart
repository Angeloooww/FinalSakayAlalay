import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // BASE64 IMAGE STORAGE (Android, iOS & Web Compatible)
  // ============================================

  /// Upload PWD card as Base64 (Android/iOS) - NO STORAGE NEEDED
  Future<void> uploadPwdCardBase64(File file, String userId) async {
    try {
      print('Starting Android/iOS upload...');
      
      // Read file as bytes
      Uint8List imageBytes = await file.readAsBytes();
      print('Image size: ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');
      
      // Check file size (Firestore has 1MB document limit)
      // Leaving buffer for other fields in the document
      if (imageBytes.length > 900000) { // 900KB to be safe
        throw Exception("Image too large (${(imageBytes.length / 1024).toStringAsFixed(0)} KB). Please use a smaller image or reduce quality.");
      }
      
      // Convert to Base64
      String base64Image = base64Encode(imageBytes);
      print('Base64 encoded successfully');
      
      // Save directly to Firestore with merge (creates if doesn't exist)
      await _firestore.collection('users').doc(userId).set({
        'pwdCardBase64': base64Image,
        'pwdCardUploadedAt': FieldValue.serverTimestamp(),
        'pwdCardVerified': false,
        'pwdCardPlatform': 'mobile',
      }, SetOptions(merge: true)); // merge: true preserves existing fields
      
      print('✅ PWD card saved successfully to Firestore (Android/iOS)');
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception("Permission denied. Please make sure you're logged in.");
      } else if (e.code == 'unavailable') {
        throw Exception("Network error. Please check your internet connection.");
      }
      throw Exception("Database error: ${e.message}");
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception("Error uploading PWD card: $e");
    }
  }

  /// Upload PWD card as Base64 (Web) - NO STORAGE NEEDED
  Future<void> uploadPwdCardBase64Web(Uint8List imageBytes, String userId) async {
    try {
      print('Starting Web upload...');
      print('Image size: ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');
      
      // Check file size (Firestore has 1MB document limit)
      if (imageBytes.length > 900000) { // 900KB to be safe
        throw Exception("Image too large (${(imageBytes.length / 1024).toStringAsFixed(0)} KB). Please use a smaller image or reduce quality.");
      }
      
      // Convert to Base64
      String base64Image = base64Encode(imageBytes);
      print('Base64 encoded successfully');
      
      // Save directly to Firestore
      await _firestore.collection('users').doc(userId).update({
        'pwdCardBase64': base64Image,
        'pwdCardUploadedAt': FieldValue.serverTimestamp(),
        'pwdCardVerified': false,
        'pwdCardPlatform': 'web',
      });
      
      print('✅ PWD card saved successfully to Firestore (Web)');
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception("Permission denied. Please make sure you're logged in.");
      } else if (e.code == 'unavailable') {
        throw Exception("Network error. Please check your internet connection.");
      }
      throw Exception("Database error: ${e.message}");
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception("Error uploading PWD card: $e");
    }
  }

  /// Get PWD card as Base64 and convert to bytes for display
  /// Works on Android, iOS, and Web
  Future<Uint8List?> getPwdCardImage(String userId) async {
    try {
      print('Fetching PWD card for user: $userId');
      
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        String? base64Image = data?['pwdCardBase64'];
        
        if (base64Image != null && base64Image.isNotEmpty) {
          print('✅ PWD card found, decoding...');
          return base64Decode(base64Image);
        } else {
          print('⚠️ No PWD card found for this user');
        }
      } else {
        print('⚠️ User document does not exist');
      }
      return null;
    } on FirebaseException catch (e) {
      print('❌ Error getting PWD card: ${e.code} - ${e.message}');
      throw Exception('Failed to retrieve PWD card: ${e.message}');
    } catch (e) {
      print('❌ Error getting PWD card: $e');
      return null;
    }
  }

  /// Check if user has uploaded PWD card
  Future<bool> hasPwdCard(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        String? base64Image = data?['pwdCardBase64'];
        return base64Image != null && base64Image.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('Error checking PWD card: $e');
      return false;
    }
  }

  /// Delete PWD card from Firestore
  Future<void> deletePwdCard(String userId) async {
    try {
      print('Deleting PWD card for user: $userId');
      
      await _firestore.collection('users').doc(userId).update({
        'pwdCardBase64': FieldValue.delete(),
        'pwdCardUploadedAt': FieldValue.delete(),
        'pwdCardVerified': FieldValue.delete(),
        'pwdCardPlatform': FieldValue.delete(),
      });
      
      print('✅ PWD card deleted successfully');
    } on FirebaseException catch (e) {
      print('❌ Delete error: ${e.code} - ${e.message}');
      throw Exception('Failed to delete PWD card: ${e.message}');
    } catch (e) {
      print('❌ Delete error: $e');
      throw Exception('Failed to delete PWD card: $e');
    }
  }

  // ============================================
  // AUTHENTICATION METHODS
  // ============================================

  /// Register user with email and password
  Future<UserCredential> registerUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // ============================================
  // FIRESTORE USER DATA METHODS
  // ============================================

  /// Save user data to Firestore
  Future<void> saveUserDataToFirestore(String userId, Map<String, dynamic> userData) async {
    try {
      // Remove password fields before saving to Firestore
      Map<String, dynamic> dataToSave = Map.from(userData);
      dataToSave.remove('password');
      dataToSave.remove('confirmPassword');

      // Add timestamp
      dataToSave['createdAt'] = FieldValue.serverTimestamp();
      dataToSave['updatedAt'] = FieldValue.serverTimestamp();

      // Save to the 'users' collection with userId as document ID
      await _firestore.collection('users').doc(userId).set(dataToSave);

      print('User data saved successfully to Firestore');
    } on FirebaseException catch (e) {
      print('Error saving user data: ${e.message}');
      throw Exception('Failed to save user data: ${e.message}');
    }
  }

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } on FirebaseException catch (e) {
      print('Error getting user data: ${e.message}');
      throw Exception('Failed to get user data: ${e.message}');
    }
  }

  /// Update user data in Firestore
  Future<void> updateUserData(String userId, Map<String, dynamic> updates) async {
    try {
      // Add updated timestamp
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('users').doc(userId).update(updates);
      print('User data updated successfully');
    } on FirebaseException catch (e) {
      print('Error updating user data: ${e.message}');
      throw Exception('Failed to update user data: ${e.message}');
    }
  }

  /// Delete user account (including auth and data)
  Future<void> deleteUserAccount(String userId) async {
    try {
      // Delete user data from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // Delete Firebase Auth account
      User? user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }

      print('User account deleted successfully');
    } catch (e) {
      print('Error deleting user account: $e');
      throw Exception('Failed to delete user account: $e');
    }
  }

  // ============================================
  // REAL-TIME LISTENERS (Optional)
  // ============================================

  /// Listen to user data changes in real-time
  Stream<DocumentSnapshot> getUserDataStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  /// Listen to authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}