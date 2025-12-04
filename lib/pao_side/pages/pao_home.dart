import 'dart:convert';
import 'package:finalsakay/main.dart';
import 'package:finalsakay/pao_side/navigation/pao_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // ✅ NEW: PWD Notifications
  List<Map<String, dynamic>> _pwdNotifications = [];
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    startPaoLiveTracking();
    _listenToPwdNotifications(); // ✅ Start listening for PWD notifications
  }

  // ✅ NEW: Listen to PWD notifications in real-time
  void _listenToPwdNotifications() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection("pwd_notifications")
        .where("paoId", isEqualTo: user.uid)
        .where("status", isEqualTo: "pending")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .listen((snapshot) {
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

      // Show alert if new notification arrives
      if (_unreadNotificationsCount > 0 && _pwdNotifications.isNotEmpty) {
        _showNewNotificationAlert(_pwdNotifications.first);
      }
    });
  }

  // ✅ NEW: Show alert for new PWD notification
  void _showNewNotificationAlert(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.accessible,
          size: 48,
          color: Colors.orange,
        ),
        title: const Text("PWD Passenger Waiting!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "A PWD passenger is waiting for a jeepney at their location.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "📍 Location: ${notification['latitude'].toStringAsFixed(6)}, ${notification['longitude'].toStringAsFixed(6)}",
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    "🚏 Route: ${notification['routeName']}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _markNotificationAsRead(notification['id']);
              Navigator.pop(context);
            },
            child: const Text("Dismiss"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
            ),
            icon: const Icon(Icons.navigation, color: Colors.white),
            label: const Text(
              "View Location",
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              Navigator.pop(context);
              _viewPwdLocation(notification);
            },
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Mark notification as read
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection("pwd_notifications")
          .doc(notificationId)
          .update({"isRead": true});
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  // ✅ NEW: View PWD location on map
  void _viewPwdLocation(Map<String, dynamic> notification) {
    final pwdLocation = LatLng(
      notification['latitude'],
      notification['longitude'],
    );

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

  // ✅ NEW: Acknowledge notification
  Future<void> _acknowledgeNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection("pwd_notifications")
          .doc(notificationId)
          .update({
        "status": "acknowledged",
        "acknowledgedAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Notification acknowledged"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error acknowledging notification: $e");
    }
  }

  // ✅ NEW: Show all PWD notifications
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
                                        "Route: ${notification['routeName']}",
                                      ),
                                      Text(
                                        "Passenger: ${notification['passengerEmail']}",
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
                                                size: 18),
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
                                            Icon(Icons.check, size: 18),
                                            SizedBox(width: 8),
                                            Text("Acknowledge"),
                                          ],
                                        ),
                                        onTap: () {
                                          _acknowledgeNotification(
                                              notification['id']);
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
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
    super.dispose();
  }

  Future<void> searchPlace(String query) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=$query, Iloilo City"
      "&format=json&limit=1",
    );

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
      }
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
          // ✅ NOTIFICATION BELL ICON
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
                    // PAO's location
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
                    // Searched location OR PWD location
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
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search places...",
                  border: InputBorder.none,
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