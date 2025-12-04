import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pao_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  final String _paoCollection = 'pao';
  final String _usersCollection = 'users';
  final String _paoLocationsCollection = 'pao_locations';

  // ============================================
  // ACTIVE ROUTE & PAO OPERATIONS (PRIMARY)
  // ============================================

  /// Get all ACTIVE routes (routes with at least one online PAO)
  Future<List<String>> getActiveRoutes() async {
    try {
      // Get all online PAOs from pao_locations
      QuerySnapshot locationSnapshot = await _firestore
          .collection(_paoLocationsCollection)
          .where('isOnline', isEqualTo: true)
          .get();

      Set<String> routes = {};

      // For each online PAO, get their route from the pao collection
      for (var locationDoc in locationSnapshot.docs) {
        final locationData = locationDoc.data() as Map<String, dynamic>?;
        String paoId = locationData?['paoId'] ?? '';
        
        if (paoId.isNotEmpty) {
          DocumentSnapshot paoDoc = await _firestore
              .collection(_paoCollection)
              .doc(paoId)
              .get();

          if (paoDoc.exists) {
            final paoData = paoDoc.data() as Map<String, dynamic>?;
            String? routeName = paoData?['routeName'];
            
            if (routeName != null && routeName.isNotEmpty) {
              routes.add(routeName);
            }
          }
        }
      }

      return routes.toList()..sort(); // Return sorted list
    } catch (e) {
      print("Error fetching active routes: $e");
      return [];
    }
  }

  /// Stream ACTIVE PAOs filtered by route name (real-time updates)
  Stream<List<PaoModel>> getActivePaosByRoute(String routeName) {
    return _firestore
        .collection(_paoLocationsCollection)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .asyncMap((locationSnapshot) async {
          List<PaoModel> paos = [];
          
          for (var locationDoc in locationSnapshot.docs) {
            final locationData = locationDoc.data();
            String paoId = locationData['paoId'] ?? '';
            
            if (paoId.isEmpty) continue;
            
            // Get the PAO details from 'pao' collection
            DocumentSnapshot paoDoc = await _firestore
                .collection(_paoCollection)
                .doc(paoId)
                .get();
            
            if (paoDoc.exists) {
              final paoData = paoDoc.data() as Map<String, dynamic>?;
              
              if (paoData != null) {
                // Filter by route name
                if (paoData['routeName'] == routeName) {
                  // Merge location data with PAO data
                  Map<String, dynamic> mergedData = {
                    ...paoData,
                    'lat': locationData['lat'],
                    'lng': locationData['lng'],
                    'isLocationEnabled': true, // They're online, so location is enabled
                  };
                  
                  paos.add(PaoModel.fromFirestore(mergedData, paoDoc.id));
                }
              }
            }
          }
          
          return paos;
        });
  }

  /// Check if a PAO is currently online
  Future<bool> isPaoOnline(String paoId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_paoLocationsCollection)
          .where('paoId', isEqualTo: paoId)
          .where('isOnline', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking PAO online status: $e");
      return false;
    }
  }

  /// Get PAO's current location
  Future<Map<String, double>?> getPaoCurrentLocation(String paoId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_paoLocationsCollection)
          .where('paoId', isEqualTo: paoId)
          .where('isOnline', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>?;
        if (data != null) {
          return {
            'lat': (data['lat'] as num?)?.toDouble() ?? 0.0,
            'lng': (data['lng'] as num?)?.toDouble() ?? 0.0,
          };
        }
      }
      return null;
    } catch (e) {
      print("Error fetching PAO location: $e");
      return null;
    }
  }

  // ============================================
  // ROUTE OPERATIONS
  // ============================================

  /// Get all unique routes from the PAO collection (regardless of online status)
  Future<List<String>> getAllRoutes() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_paoCollection).get();
      Set<String> routes = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        String? routeName = data?['routeName'];
        
        if (routeName != null && routeName.isNotEmpty) {
          routes.add(routeName);
        }
      }

      return routes.toList()..sort();
    } catch (e) {
      print("Error fetching all routes: $e");
      rethrow;
    }
  }

  /// Get routes with count of PAOs
  Future<Map<String, int>> getRoutesWithCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_paoCollection).get();
      Map<String, int> routeCounts = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        String? routeName = data?['routeName'];
        
        if (routeName != null && routeName.isNotEmpty) {
          routeCounts[routeName] = (routeCounts[routeName] ?? 0) + 1;
        }
      }

      return routeCounts;
    } catch (e) {
      print("Error fetching route counts: $e");
      rethrow;
    }
  }

  /// Search routes by keyword
  Future<List<String>> searchRoutes(String searchQuery) async {
    try {
      final lowerQuery = searchQuery.toLowerCase();
      final allRoutes = await getAllRoutes();
      
      return allRoutes
          .where((route) => route.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      print("Error searching routes: $e");
      rethrow;
    }
  }

  // ============================================
  // PAO OPERATIONS
  // ============================================

  /// Get single PAO by ID
  Future<PaoModel?> getPaoById(String paoId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_paoCollection)
          .doc(paoId)
          .get();

      if (doc.exists && doc.data() != null) {
        return PaoModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      print("Error fetching PAO by ID: $e");
      return null;
    }
  }

  /// Stream PAOs filtered by route name (real-time, all PAOs regardless of online status)
  Stream<List<PaoModel>> getPaosByRoute(String routeName) {
    return _firestore
        .collection(_paoCollection)
        .where('routeName', isEqualTo: routeName)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return PaoModel.fromFirestore(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                } catch (e) {
                  print("Error parsing PAO document ${doc.id}: $e");
                  return null;
                }
              })
              .whereType<PaoModel>()
              .toList();
        });
  }

  /// Get PAOs by route (one-time fetch)
  Future<List<PaoModel>> getPaosByRouteOnce(String routeName) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_paoCollection)
          .where('routeName', isEqualTo: routeName)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return PaoModel.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            } catch (e) {
              print("Error parsing PAO document ${doc.id}: $e");
              return null;
            }
          })
          .whereType<PaoModel>()
          .toList();
    } catch (e) {
      print("Error fetching PAOs by route: $e");
      rethrow;
    }
  }

  /// Get all PAOs (Stream)
  Stream<List<PaoModel>> getAllPaos() {
    return _firestore
        .collection(_paoCollection)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return PaoModel.fromFirestore(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                } catch (e) {
                  print("Error parsing PAO document ${doc.id}: $e");
                  return null;
                }
              })
              .whereType<PaoModel>()
              .toList();
        });
  }

  /// Get verified PAOs only
  Stream<List<PaoModel>> getVerifiedPaos() {
    return _firestore
        .collection(_paoCollection)
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return PaoModel.fromFirestore(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                } catch (e) {
                  print("Error parsing PAO document ${doc.id}: $e");
                  return null;
                }
              })
              .whereType<PaoModel>()
              .toList();
        });
  }

  /// Get verified PAOs by route
  Stream<List<PaoModel>> getVerifiedPaosByRoute(String routeName) {
    return _firestore
        .collection(_paoCollection)
        .where('routeName', isEqualTo: routeName)
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return PaoModel.fromFirestore(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                } catch (e) {
                  print("Error parsing PAO document ${doc.id}: $e");
                  return null;
                }
              })
              .whereType<PaoModel>()
              .toList();
        });
  }

  /// Update PAO route
  Future<void> updatePaoRoute(String paoId, String newRoute) async {
    try {
      await _firestore.collection(_paoCollection).doc(paoId).update({
        'routeName': newRoute,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating PAO route: $e");
      rethrow;
    }
  }

  /// Verify PAO
  Future<void> verifyPao(String paoId) async {
    try {
      await _firestore.collection(_paoCollection).doc(paoId).update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error verifying PAO: $e");
      rethrow;
    }
  }

  /// Set PAO active status (call when PAO logs in/out)
  Future<void> setPaoActiveStatus(String paoId, bool isActive) async {
    try {
      await _firestore.collection(_paoCollection).doc(paoId).update({
        'isActive': isActive,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating PAO active status: $e");
      rethrow;
    }
  }

  // ============================================
  // PAO LOCATION OPERATIONS (For Real-time Tracking)
  // ============================================

  /// Stream PAO locations by route (for map markers)
  Stream<List<Map<String, dynamic>>> getPaoLocationsByRoute(String routeName) {
    return _firestore
        .collection(_paoLocationsCollection)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .asyncMap((locationSnapshot) async {
          List<Map<String, dynamic>> locations = [];

          for (var doc in locationSnapshot.docs) {
            final data = doc.data();
            String paoId = data['paoId'] ?? '';

            // Get PAO details to check route
            DocumentSnapshot paoDoc = await _firestore
                .collection(_paoCollection)
                .doc(paoId)
                .get();

            if (paoDoc.exists) {
              final paoData = paoDoc.data() as Map<String, dynamic>?;
              if (paoData?['routeName'] == routeName) {
                locations.add({
                  'paoId': paoId,
                  'lat': data['lat'],
                  'lng': data['lng'],
                  'routeName': paoData?['routeName'],
                  'timestamp': data['timestamp'],
                  'heading': data['heading'],
                });
              }
            }
          }

          return locations;
        });
  }

  /// Update PAO location (called by PAO app)
  Future<void> updatePaoLocation({
    required String paoId,
    required double latitude,
    required double longitude,
    double? heading,
    bool isOnline = true,
  }) async {
    try {
      // Get PAO's route name
      DocumentSnapshot paoDoc = await _firestore
          .collection(_paoCollection)
          .doc(paoId)
          .get();

      String? routeName;
      if (paoDoc.exists) {
        final paoData = paoDoc.data() as Map<String, dynamic>?;
        routeName = paoData?['routeName'];
      }

      await _firestore.collection(_paoLocationsCollection).doc(paoId).set({
        'paoId': paoId,
        'lat': latitude,
        'lng': longitude,
        'routeName': routeName ?? '',
        'heading': heading,
        'isOnline': isOnline,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating PAO location: $e");
      rethrow;
    }
  }

  /// Set PAO online/offline status in location collection
  Future<void> setPaoLocationStatus(String paoId, bool isOnline) async {
    try {
      await _firestore.collection(_paoLocationsCollection).doc(paoId).update({
        'isOnline': isOnline,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating PAO location status: $e");
      rethrow;
    }
  }

  // ============================================
  // SEARCH OPERATIONS
  // ============================================

  /// Search PAOs by name (lastName or middleName)
  Future<List<PaoModel>> searchPaosByName(String searchQuery) async {
    try {
      final lowerQuery = searchQuery.toLowerCase();
      
      QuerySnapshot snapshot = await _firestore
          .collection(_paoCollection)
          .get();

      return snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final lastName = (data?['lastName'] ?? '').toString().toLowerCase();
            final middleName = (data?['middleName'] ?? '').toString().toLowerCase();
            
            return lastName.contains(lowerQuery) || 
                   middleName.contains(lowerQuery);
          })
          .map((doc) {
            try {
              return PaoModel.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            } catch (e) {
              print("Error parsing PAO document ${doc.id}: $e");
              return null;
            }
          })
          .whereType<PaoModel>()
          .toList();
    } catch (e) {
      print("Error searching PAOs: $e");
      rethrow;
    }
  }

  // ============================================
  // STATISTICS OPERATIONS
  // ============================================

  /// Get count of PAOs by route
  Future<int> getPaoCountByRoute(String routeName) async {
    try {
      AggregateQuerySnapshot snapshot = await _firestore
          .collection(_paoCollection)
          .where('routeName', isEqualTo: routeName)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print("Error getting PAO count: $e");
      return 0;
    }
  }

  /// Get count of ONLINE PAOs by route
  Future<int> getOnlinePaoCountByRoute(String routeName) async {
    try {
      QuerySnapshot locationSnapshot = await _firestore
          .collection(_paoLocationsCollection)
          .where('isOnline', isEqualTo: true)
          .get();

      int count = 0;
      for (var doc in locationSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        String paoId = data?['paoId'] ?? '';
        
        if (paoId.isNotEmpty) {
          DocumentSnapshot paoDoc = await _firestore
              .collection(_paoCollection)
              .doc(paoId)
              .get();

          if (paoDoc.exists) {
            final paoData = paoDoc.data() as Map<String, dynamic>?;
            if (paoData?['routeName'] == routeName) {
              count++;
            }
          }
        }
      }

      return count;
    } catch (e) {
      print("Error getting online PAO count: $e");
      return 0;
    }
  }

  /// Get total number of PAOs
  Future<int> getTotalPaoCount() async {
    try {
      AggregateQuerySnapshot snapshot = await _firestore
          .collection(_paoCollection)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print("Error getting total PAO count: $e");
      return 0;
    }
  }

  /// Get total number of verified PAOs
  Future<int> getVerifiedPaoCount() async {
    try {
      AggregateQuerySnapshot snapshot = await _firestore
          .collection(_paoCollection)
          .where('isVerified', isEqualTo: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print("Error getting verified PAO count: $e");
      return 0;
    }
  }

  // ============================================
  // USER OPERATIONS
  // ============================================

  /// Get user by ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error fetching user: $e");
      rethrow;
    }
  }

  /// Update user data
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating user: $e");
      rethrow;
    }
  }
}