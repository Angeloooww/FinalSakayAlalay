import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    startPaoLiveTracking();
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

  // ✅ LOGOUT FUNCTION
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
        // ✅ Set PAO inactive in the main pao collection
        await FirebaseFirestore.instance
            .collection("pao")
            .doc(user.uid)
            .update({
          "isActive": false,
          "lastActiveAt": FieldValue.serverTimestamp(),
        });

        // ✅ Set PAO offline in pao_locations collection
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
        // Continue with logout even if status update fails
      }
    }

    // Sign out
    await FirebaseAuth.instance.signOut();
    print("✅ Successfully signed out");

    // ✅ Let AuthWrapper handle navigation
    if (mounted) {
      // Pop all routes and go back to root
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // AuthWrapper will automatically show LoginPage
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
          // ✅ LOGOUT BUTTON IN APP BAR
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
                    if (searchedLocation != null)
                      Marker(
                        point: searchedLocation!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          size: 45,
                          color: Colors.red,
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