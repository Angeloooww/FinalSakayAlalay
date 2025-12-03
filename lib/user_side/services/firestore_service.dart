import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pao_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  final String _paoCollection = 'pao';
  final String _usersCollection = 'users';
  final String _paoLocationsCollection = 'pao_locations';

  // ============================================
  // ROUTE OPERATIONS
  // ============================================

  /// Get all unique routes from the PAO collection
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

      // Return sorted list of unique routes
      return routes.toList()..sort();
    } catch (e) {
      print("Error fetching routes: $e");
      rethrow;
    }
  }

  /// Get routes with count of available PAOs
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

  // ============================================
  // PAO OPERATIONS
  // ============================================

  /// Stream PAOs filtered by route name (real-time updates)
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
              .whereType<PaoModel>() // Filter out null values
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
      rethrow;
    }
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

  // ============================================
  // PAO LOCATION OPERATIONS (For Real-time Tracking)
  // ============================================

  /// Stream PAO locations by route (for map markers)
  Stream<List<Map<String, dynamic>>> getPaoLocationsByRoute(String routeName) {
    return _firestore
        .collection(_paoLocationsCollection)
        .where('routeName', isEqualTo: routeName)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'paoId': doc.id,
              'latitude': data['latitude'],
              'longitude': data['longitude'],
              'routeName': data['routeName'],
              'timestamp': data['timestamp'],
              'heading': data['heading'], // Direction the vehicle is facing
            };
          }).toList();
        });
  }

  /// Update PAO location (called by PAO app)
  Future<void> updatePaoLocation({
    required String paoId,
    required double latitude,
    required double longitude,
    required String routeName,
    double? heading,
  }) async {
    try {
      await _firestore.collection(_paoLocationsCollection).doc(paoId).set({
        'latitude': latitude,
        'longitude': longitude,
        'routeName': routeName,
        'heading': heading,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating PAO location: $e");
      rethrow;
    }
  }

  /// Get PAO location by ID (one-time fetch)
  Future<Map<String, dynamic>?> getPaoLocation(String paoId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_paoLocationsCollection)
          .doc(paoId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'paoId': doc.id,
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'routeName': data['routeName'],
          'timestamp': data['timestamp'],
          'heading': data['heading'],
        };
      }
      return null;
    } catch (e) {
      print("Error fetching PAO location: $e");
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
  // USER OPERATIONS (Optional - if needed)
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

        // ============================================
      // ACTIVE PAO OPERATIONS (for online status)
      // ============================================

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

      /// Stream ACTIVE PAOs filtered by route name (real-time updates)
      Stream<List<PaoModel>> getActivePaosByRoute(String routeName) {
        return _firestore
            .collection(_paoCollection)
            .where('routeName', isEqualTo: routeName)
            .where('isActive', isEqualTo: true) // ✅ Only active PAOs
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

      /// Get all ACTIVE routes (routes with at least one active PAO)
      Future<List<String>> getActiveRoutes() async {
        try {
          QuerySnapshot snapshot = await _firestore
              .collection(_paoCollection)
              .where('isActive', isEqualTo: true)
              .get();
          
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
          print("Error fetching active routes: $e");
          rethrow;
        }
      }

      /// Get count of active PAOs by route
      Future<int> getActivePaoCountByRoute(String routeName) async {
        try {
          AggregateQuerySnapshot snapshot = await _firestore
              .collection(_paoCollection)
              .where('routeName', isEqualTo: routeName)
              .where('isActive', isEqualTo: true)
              .count()
              .get();

          return snapshot.count ?? 0;
        } catch (e) {
          print("Error getting active PAO count: $e");
          return 0;
        }
      }
}