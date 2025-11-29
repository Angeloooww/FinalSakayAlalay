import 'dart:convert';
import 'package:finalsakay/pao_side/navigation/pao_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// ✅ FIREBASE
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
    startPaoLiveTracking(); // ✅ LIVE GPS + FIRESTORE
  }

  // ✅ LIVE LOCATION STREAM → FIRESTORE
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

      // ✅ SEND TO FIRESTORE
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

  // ✅ SET PAO OFFLINE
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

  // ✅ PLACE SEARCH
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PAO Map")),

      body: Stack(
        children: [
          if (isLoadingLocation)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    paoLocation ?? LatLng(10.708365, 122.563966),
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
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

      bottomNavigationBar: PAOBotoomNav(currentIndex: 2),
    );
  }
}
