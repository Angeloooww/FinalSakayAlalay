import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SEPARATE COLLECTIONS FOR EACH USER TYPE
  final String pwdUsersCollection = 'pwd_users';  // For PWD commuters
  final String paoCollection = 'pao';              // For PAO officers
  final String usersCollection = 'users';          // Lightweight routing table

  // ============================================
  // PWD CARD UPLOAD (For PWD Users)
  // ============================================

  /// Upload PWD card as Base64 (Android/iOS)
  Future<void> uploadPwdCardBase64(File file, String userId) async {
    try {
      print('Starting Android/iOS PWD card upload...');
      
      Uint8List imageBytes = await file.readAsBytes();
      print('Image size: ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');
      
      if (imageBytes.length > 900000) {
        throw Exception("Image too large (${(imageBytes.length / 1024).toStringAsFixed(0)} KB). Please use a smaller image or reduce quality.");
      }
      
      String base64Image = base64Encode(imageBytes);
      print('Base64 encoded successfully');
      
      // Save to PWD_USERS collection (not 'users')
      await _firestore.collection(pwdUsersCollection).doc(userId).set({
        'pwdCardBase64': base64Image,
        'pwdCardUploadedAt': FieldValue.serverTimestamp(),
        'pwdCardVerified': false,
        'pwdCardPlatform': 'mobile',
      }, SetOptions(merge: true));
      
      print('✅ PWD card saved successfully to pwd_users collection');
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

  /// Upload PWD card as Base64 (Web)
  Future<void> uploadPwdCardBase64Web(Uint8List imageBytes, String userId) async {
    try {
      print('Starting Web PWD card upload...');
      print('Image size: ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');
      
      if (imageBytes.length > 900000) {
        throw Exception("Image too large (${(imageBytes.length / 1024).toStringAsFixed(0)} KB). Please use a smaller image or reduce quality.");
      }
      
      String base64Image = base64Encode(imageBytes);
      print('Base64 encoded successfully');
      
      // Save to PWD_USERS collection (not 'users')
      await _firestore.collection(pwdUsersCollection).doc(userId).update({
        'pwdCardBase64': base64Image,
        'pwdCardUploadedAt': FieldValue.serverTimestamp(),
        'pwdCardVerified': false,
        'pwdCardPlatform': 'web',
      });
      
      print('✅ PWD card saved successfully to pwd_users collection');
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

  /// Get PWD card image
  Future<Uint8List?> getPwdCardImage(String userId) async {
    try {
      print('Fetching PWD card for user: $userId');
      
      DocumentSnapshot doc = await _firestore.collection(pwdUsersCollection).doc(userId).get();
      
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
    } catch (e) {
      print('❌ Error getting PWD card: $e');
      return null;
    }
  }

  /// Check if user has uploaded PWD card
  Future<bool> hasPwdCard(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(pwdUsersCollection).doc(userId).get();
      
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

  /// Delete PWD card
  Future<void> deletePwdCard(String userId) async {
    try {
      print('Deleting PWD card for user: $userId');
      
      await _firestore.collection(pwdUsersCollection).doc(userId).update({
        'pwdCardBase64': FieldValue.delete(),
        'pwdCardUploadedAt': FieldValue.delete(),
        'pwdCardVerified': FieldValue.delete(),
        'pwdCardPlatform': FieldValue.delete(),
      });
      
      print('✅ PWD card deleted successfully');
    } catch (e) {
      print('❌ Delete error: $e');
      throw Exception('Failed to delete PWD card: $e');
    }
  }

  // ============================================
  // PAO ID UPLOAD (For PAO Officers)
  // ============================================

  /// Upload PAO ID as Base64 (Android/iOS)
  Future<void> uploadPaoIdBase64(File file, String userId) async {
    try {
      print('Starting PAO Android/iOS upload...');

      Uint8List imageBytes = await file.readAsBytes();

      if (imageBytes.length > 900000) {
        throw Exception("Image too large. Please reduce size.");
      }

      String base64Image = base64Encode(imageBytes);

      // Save to PAO collection
      await _firestore.collection(paoCollection).doc(userId).set({
        'paoIdBase64': base64Image,
        'paoIdUploadedAt': FieldValue.serverTimestamp(),
        'paoIdVerified': false,
        'paoIdPlatform': 'mobile',
      }, SetOptions(merge: true));

      print('✅ PAO ID saved successfully to pao collection');
    } catch (e) {
      print('❌ PAO Upload failed: $e');
      throw Exception("PAO upload failed: $e");
    }
  }

  /// Upload PAO ID as Base64 (Web)
  Future<void> uploadPaoIdBase64Web(Uint8List imageBytes, String userId) async {
    try {
      print('Starting PAO Web upload...');

      if (imageBytes.length > 900000) {
        throw Exception("Image too large. Please reduce size.");
      }

      String base64Image = base64Encode(imageBytes);

      // Save to PAO collection
      await _firestore.collection(paoCollection).doc(userId).update({
        'paoIdBase64': base64Image,
        'paoIdUploadedAt': FieldValue.serverTimestamp(),
        'paoIdVerified': false,
        'paoIdPlatform': 'web',
      });

      print('✅ PAO ID saved successfully to pao collection');
    } catch (e) {
      print('❌ PAO Upload failed: $e');
      throw Exception("PAO upload failed: $e");
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
  // PWD USER DATA METHODS
  // ============================================

  /// Save PWD user data to pwd_users collection
  Future<void> savePwdUserData(String userId, Map<String, dynamic> userData) async {
    try {
      print('💾 Saving PWD user data for userId: $userId');
      
      Map<String, dynamic> dataToSave = Map.from(userData);
      dataToSave.remove('password');
      dataToSave.remove('confirmPassword');

      dataToSave['createdAt'] = FieldValue.serverTimestamp();
      dataToSave['updatedAt'] = FieldValue.serverTimestamp();
      dataToSave['role'] = 'pwd';

      print('💾 Saving to pwd_users collection...');
      // Save to PWD_USERS collection
      await _firestore.collection(pwdUsersCollection).doc(userId).set(dataToSave);
      print('✅ Saved to pwd_users collection');

      print('💾 Saving routing info to users collection...');
      // Also save lightweight routing info to USERS collection
      await _firestore.collection(usersCollection).doc(userId).set({
        'email': userData['email'],
        'role': 'pwd',
        'name': '${userData['firstName']} ${userData['lastName']}',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Saved to users collection');

      print('✅ PWD user data saved successfully to both collections');
    } on FirebaseException catch (e) {
      print('❌ Error saving PWD user data: ${e.code} - ${e.message}');
      throw Exception('Failed to save PWD user data: ${e.message}');
    } catch (e) {
      print('❌ Unexpected error saving PWD user data: $e');
      throw Exception('Failed to save PWD user data: $e');
    }
  }

  /// Get PWD user data
  Future<Map<String, dynamic>?> getPwdUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(pwdUsersCollection).doc(userId).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } on FirebaseException catch (e) {
      print('Error getting PWD user data: ${e.message}');
      throw Exception('Failed to get PWD user data: ${e.message}');
    }
  }

  // ============================================
  // PAO USER DATA METHODS
  // ============================================

  /// Save PAO user data to pao collection
  Future<void> savePaoUserData(String userId, Map<String, dynamic> userData) async {
    try {
      print('💾 Saving PAO user data for userId: $userId');
      
      Map<String, dynamic> dataToSave = Map.from(userData);
      dataToSave.remove('password');
      dataToSave.remove('confirmPassword');

      dataToSave['createdAt'] = FieldValue.serverTimestamp();
      dataToSave['updatedAt'] = FieldValue.serverTimestamp();
      dataToSave['role'] = 'pao';

      print('💾 Saving to pao collection...');
      // Save to PAO collection
      await _firestore.collection(paoCollection).doc(userId).set(dataToSave);
      print('✅ Saved to pao collection');

      print('💾 Saving routing info to users collection...');
      // Also save lightweight routing info to USERS collection
      await _firestore.collection(usersCollection).doc(userId).set({
        'email': userData['email'],
        'role': 'pao',
        'name': '${userData['firstName']} ${userData['lastName']}',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Saved to users collection');

      print('✅ PAO user data saved successfully to both collections');
    } on FirebaseException catch (e) {
      print('❌ Error saving PAO user data: ${e.code} - ${e.message}');
      throw Exception('Failed to save PAO user data: ${e.message}');
    } catch (e) {
      print('❌ Unexpected error saving PAO user data: $e');
      throw Exception('Failed to save PAO user data: $e');
    }
  }

  /// Get PAO user data
  Future<Map<String, dynamic>?> getPaoUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(paoCollection).doc(userId).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } on FirebaseException catch (e) {
      print('Error getting PAO user data: ${e.message}');
      throw Exception('Failed to get PAO user data: ${e.message}');
    }
  }

  // ============================================
  // USER ROLE DETECTION
  // ============================================

  /// Get user role from users collection (for routing)
  Future<String?> getUserRole(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(usersCollection).doc(userId).get();

      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        return data?['role'];
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  /// Get complete user data based on role
  Future<Map<String, dynamic>?> getUserDataByRole(String userId) async {
    try {
      // First get the role
      String? role = await getUserRole(userId);

      if (role == null) return null;

      // Then fetch from appropriate collection
      if (role == 'pwd') {
        return await getPwdUserData(userId);
      } else if (role == 'pao') {
        return await getPaoUserData(userId);
      }

      return null;
    } catch (e) {
      print('Error getting user data by role: $e');
      return null;
    }
  }

  // ============================================
  // UPDATE & DELETE METHODS
  // ============================================

  /// Update PWD user data
  Future<void> updatePwdUserData(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection(pwdUsersCollection).doc(userId).update(updates);
      print('PWD user data updated successfully');
    } on FirebaseException catch (e) {
      print('Error updating PWD user data: ${e.message}');
      throw Exception('Failed to update PWD user data: ${e.message}');
    }
  }

  /// Update PAO user data
  Future<void> updatePaoUserData(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection(paoCollection).doc(userId).update(updates);
      print('PAO user data updated successfully');
    } on FirebaseException catch (e) {
      print('Error updating PAO user data: ${e.message}');
      throw Exception('Failed to update PAO user data: ${e.message}');
    }
  }

  /// Delete user account (works for both PWD and PAO)
  Future<void> deleteUserAccount(String userId) async {
    try {
      // Get user role first
      String? role = await getUserRole(userId);

      // Delete from appropriate collection
      if (role == 'pwd') {
        await _firestore.collection(pwdUsersCollection).doc(userId).delete();
      } else if (role == 'pao') {
        await _firestore.collection(paoCollection).doc(userId).delete();
      }

      // Delete from users routing table
      await _firestore.collection(usersCollection).doc(userId).delete();

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
  // REAL-TIME LISTENERS
  // ============================================

  /// Listen to PWD user data changes
  Stream<DocumentSnapshot> getPwdUserDataStream(String userId) {
    return _firestore.collection(pwdUsersCollection).doc(userId).snapshots();
  }

  /// Listen to PAO user data changes
  Stream<DocumentSnapshot> getPaoUserDataStream(String userId) {
    return _firestore.collection(paoCollection).doc(userId).snapshots();
  }

  /// Listen to authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============================================
  // BACKWARDS COMPATIBILITY METHODS
  // (These will automatically route to correct collection based on context)
  // ============================================

  /// Backwards compatible: Save user data (auto-detects if PWD or PAO)
  @Deprecated('Use savePwdUserData() or savePaoUserData() instead')
  Future<void> saveUserDataToFirestore(String userId, Map<String, dynamic> userData) async {
    // Check if this is a PAO user based on userData fields
    if (userData.containsKey('paoIdNum') || userData.containsKey('position') || userData.containsKey('officeLocCorp')) {
      await savePaoUserData(userId, userData);
    } else {
      // Default to PWD user
      await savePwdUserData(userId, userData);
    }
  }

  /// Backwards compatible: Get user data (auto-detects collection)
  @Deprecated('Use getPwdUserData(), getPaoUserData(), or getUserDataByRole() instead')
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    return await getUserDataByRole(userId);
  }

  /// Backwards compatible: Update user data (auto-detects collection)
  @Deprecated('Use updatePwdUserData() or updatePaoUserData() instead')
  Future<void> updateUserData(String userId, Map<String, dynamic> updates) async {
    String? role = await getUserRole(userId);
    
    if (role == 'pao') {
      await updatePaoUserData(userId, updates);
    } else if (role == 'pwd') {
      await updatePwdUserData(userId, updates);
    } else {
      throw Exception('User role not found');
    }
  }
}