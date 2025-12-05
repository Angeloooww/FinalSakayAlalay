import 'dart:async';
import 'package:finalsakay/main.dart';
import 'package:finalsakay/pao_side/navigation/pao_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class PAOHomePage extends StatefulWidget {
  const PAOHomePage({super.key});

  @override
  State<PAOHomePage> createState() => _MapsPageState();
}

class _MapsPageState extends State<PAOHomePage> {
  late final MapController _mapController;

  LatLng? paoLocation;
  bool isLoadingLocation = true;

  LatLng? searchedLocation;
  final TextEditingController _searchController = TextEditingController();

  // ✅ PWD Notifications
  List<Map<String, dynamic>> _pwdNotifications = [];
  int _unreadNotificationsCount = 0;
  final Set<String> _processedNotificationIds = {}; // Track shown notifications

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    startPaoLiveTracking();
    _listenToPwdNotifications();
  }

  // ✅ FIXED: Listen to PWD notifications in real-time
  void _listenToPwdNotifications() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ No user logged in");
      return;
    }

    print("✅ Starting PWD notification listener for user: ${user.uid}");

    FirebaseFirestore.instance
        .collection("pwd_notifications")
        .where("paoId", isEqualTo: user.uid)
        .where("status", isEqualTo: "pending")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .listen((snapshot) {
      print("📩 Received ${snapshot.docs.length} notifications");

      // Check for NEW notifications
      List<Map<String, dynamic>> newNotifications = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> notifData = {
          "id": doc.id,
          ...doc.data(),
        };

        // Only show alert for NEW unprocessed notifications
        if (!_processedNotificationIds.contains(doc.id) &&
            notifData['isRead'] == false) {
          newNotifications.add(notifData);
          _processedNotificationIds.add(doc.id); // Mark as processed
          print("🆕 New notification: ${doc.id}");
        }
      }

      setState(() {
        _pwdNotifications = snapshot.docs.map((doc) {
          return {
            "id": doc.id,
            ...doc.data(),
          };
        }).toList();

        _unreadNotificationsCount = _pwdNotifications
            .where((notif) => notif["isRead"] == false)
            .length;
      });

      print("📊 Total notifications: ${_pwdNotifications.length}");
      print("🔔 Unread count: $_unreadNotificationsCount");

      // Show alert ONLY for NEW notifications
      if (newNotifications.isNotEmpty) {
        _showNewNotificationAlert(newNotifications.first);
      }
    }, onError: (error) {
      print("❌ Error listening to notifications: $error");
    });
  }

  // ✅ FIXED: Show alert with Accept/Decline options
  void _showNewNotificationAlert(Map<String, dynamic> notification) {
    if (!mounted) return;

    print("🔔 Showing alert for notification: ${notification['id']}");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          icon: const Icon(
            Icons.accessible,
            size: 48,
            color: Colors.orange,
          ),
          title: const Text(
            "PWD Passenger Waiting!",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        Icons.person,
                        "Passenger",
                        notification['passengerName'] ?? "Unknown",
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        Icons.email,
                        "Contact",
                        notification['passengerEmail'] ?? "Unknown",
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        Icons.route,
                        "Route",
                        notification['routeName'] ?? "Unknown",
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        Icons.location_on,
                        "Coordinates",
                        "${notification['latitude']?.toStringAsFixed(4) ?? 'N/A'}, ${notification['longitude']?.toStringAsFixed(4) ?? 'N/A'}",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Do you have available seats for this PWD passenger?",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                _viewPwdLocationWithoutClosing(notification);
              },
              icon: const Icon(Icons.map, size: 18),
              label: const Text("View Map"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _respondToNotification(
                  notification['id'],
                  "declined",
                  "No available seats",
                );
              },
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text("No Seats"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
              label: const Text(
                "Accept",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _respondToNotification(
                  notification['id'],
                  "accepted",
                  "Seats available",
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Helper widget for detail rows
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ View location without closing dialog
  void _viewPwdLocationWithoutClosing(Map<String, dynamic> notification) {
    final latitude = notification['latitude'];
    final longitude = notification['longitude'];

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid location coordinates"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final pwdLocation = LatLng(latitude, longitude);

    setState(() {
      searchedLocation = pwdLocation;
    });

    _mapController.move(pwdLocation, 17);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.location_on, color: Colors.white),
            SizedBox(width: 8),
            Text("Showing PWD passenger location on map"),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ Respond to PWD notification (Accept or Decline)
  Future<void> _respondToNotification(
    String notificationId,
    String status,
    String message,
  ) async {
    print("📤 Responding to notification $notificationId: $status");

    try {
      await FirebaseFirestore.instance
          .collection("pwd_notifications")
          .doc(notificationId)
          .update({
        "status": status, // "accepted" or "declined"
        "responseMessage": message,
        "respondedAt": FieldValue.serverTimestamp(),
        "isRead": true,
      });

      print("✅ Response sent successfully");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  status == "accepted" ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status == "accepted"
                        ? "Accepted - PWD passenger notified"
                        : "Declined - Passenger will be notified",
                  ),
                ),
              ],
            ),
            backgroundColor: status == "accepted" ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print("❌ Error responding to notification: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to respond: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ Mark notification as read
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection("pwd_notifications")
          .doc(notificationId)
          .update({"isRead": true});
      print("✅ Marked notification as read: $notificationId");
    } catch (e) {
      print("❌ Error marking notification as read: $e");
    }
  }

  // ✅ View PWD location on map (from list)
  void _viewPwdLocation(Map<String, dynamic> notification) {
    final latitude = notification['latitude'];
    final longitude = notification['longitude'];

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid location coordinates"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final pwdLocation = LatLng(latitude, longitude);

    setState(() {
      searchedLocation = pwdLocation;
    });

    _mapController.move(pwdLocation, 17);
    _markNotificationAsRead(notification['id']);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.accessible, color: Colors.white),
            SizedBox(width: 8),
            Text("Showing PWD passenger location"),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ✅ Show all PWD notifications
  void _showNotificationsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.accessible, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        "PWD Notifications",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_unreadNotificationsCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "$_unreadNotificationsCount new",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _pwdNotifications.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "No PWD notifications",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _pwdNotifications.length,
                            itemBuilder: (context, index) {
                              final notification = _pwdNotifications[index];
                              final isRead = notification['isRead'] ?? false;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: isRead ? 1 : 3,
                                color: isRead ? null : Colors.orange.shade50,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orange,
                                    child: const Icon(
                                      Icons.accessible,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    "PWD Passenger Waiting",
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        "Route: ${notification['routeName'] ?? 'Unknown'}",
                                      ),
                                      Text(
                                        "Passenger: ${notification['passengerName'] ?? 'Unknown'}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.navigation,
                                                size: 18, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text("View Location"),
                                          ],
                                        ),
                                        onTap: () {
                                          Future.delayed(
                                            const Duration(milliseconds: 100),
                                            () {
                                              Navigator.pop(context);
                                              _viewPwdLocation(notification);
                                            },
                                          );
                                        },
                                      ),
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.check_circle,
                                                size: 18, color: Colors.green),
                                            SizedBox(width: 8),
                                            Text("Accept (Seats Available)"),
                                          ],
                                        ),
                                        onTap: () {
                                          Future.delayed(
                                            const Duration(milliseconds: 100),
                                            () {
                                              _respondToNotification(
                                                notification['id'],
                                                "accepted",
                                                "Seats available",
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.cancel,
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text("Decline (No Seats)"),
                                          ],
                                        ),
                                        onTap: () {
                                          Future.delayed(
                                            const Duration(milliseconds: 100),
                                            () {
                                              _respondToNotification(
                                                notification['id'],
                                                "declined",
                                                "No available seats",
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void startPaoLiveTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("❌ Location services disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ No user for location tracking");
      return;
    }

    print("✅ Starting live location tracking for PAO: ${user.uid}");

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      LatLng newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        paoLocation = newLocation;
        isLoadingLocation = false;
      });

      _mapController.move(newLocation, 17);

      await FirebaseFirestore.instance
          .collection("pao_locations")
          .doc(user.uid)
          .set({
        "lat": position.latitude,
        "lng": position.longitude,
        "isOnline": true,
        "updatedAt": FieldValue.serverTimestamp(),
        "paoId": user.uid,
      });
    });
  }

  @override
  void dispose() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection("pao_locations")
          .doc(user.uid)
          .update({"isOnline": false});
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> searchPlace(String query) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=$query, Iloilo City"
      "&format=json&limit=1",
    );

    try {
      final response = await http.get(url, headers: {
        "User-Agent": "sakay-alalay-app",
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.isNotEmpty) {
          final double lat = double.parse(data[0]["lat"]);
          final double lon = double.parse(data[0]["lon"]);

          setState(() {
            searchedLocation = LatLng(lat, lon);
          });

          _mapController.move(searchedLocation!, 17);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Found: ${data[0]['display_name']}"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Location not found"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print("Search error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Search failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection("pao")
              .doc(user.uid)
              .update({
            "isActive": false,
            "lastActiveAt": FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance
              .collection("pao_locations")
              .doc(user.uid)
              .set({
            "isOnline": false,
            "updatedAt": FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          print("✅ PAO status set to inactive and offline");
        } catch (e) {
          print("❌ Failed to update PAO status: $e");
        }
      }

      await FirebaseAuth.instance.signOut();
      print("✅ Successfully signed out");

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SakayAlalayApp()),
          (route) => false,
        );
      }
    } catch (e) {
      print("❌ Logout error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PAO Map"),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          // ✅ NOTIFICATION BELL ICON with Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: 'PWD Notifications',
                onPressed: _showNotificationsList,
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_unreadNotificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (isLoadingLocation)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: paoLocation ?? LatLng(10.708365, 122.563966),
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.sakayalalay",
                ),
                MarkerLayer(
                  markers: [
                    // PAO's location (Blue Bus)
                    if (paoLocation != null)
                      Marker(
                        point: paoLocation!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.directions_bus,
                          size: 45,
                          color: Colors.blue,
                        ),
                      ),
                    // PWD Passenger location (Orange Accessible Icon)
                    if (searchedLocation != null)
                      Marker(
                        point: searchedLocation!,
                        width: 60,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.accessible,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search places...",
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    searchPlace(value.trim());
                  }
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: PAOBotoomNav(currentIndex: 0),
    );
  }
}