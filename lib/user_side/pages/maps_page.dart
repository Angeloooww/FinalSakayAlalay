import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// ✅ FIREBASE
import 'package:cloud_firestore/cloud_firestore.dart';

import '../navigation/nav_bar.dart';

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  late final MapController _mapController;

  LatLng? userLocation;
  bool isLoadingLocation = true;

  LatLng? searchedLocation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    _mapController = MapController();
    getUserLiveLocation(); // ✅ USER GPS
    super.initState();
  }

  // ✅ GET USER GPS
  Future<void> getUserLiveLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => isLoadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      userLocation = LatLng(position.latitude, position.longitude);
      isLoadingLocation = false;
    });

    _mapController.move(userLocation!, 17);
  }

  // ✅ LIVE PAO MARKERS
  Stream<List<Marker>> getLivePaoMarkers() {
    return FirebaseFirestore.instance
        .collection("pao_locations")
        .where("isOnline", isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return Marker(
          point: LatLng(data["lat"], data["lng"]),
          width: 50,
          height: 50,
          child: const Icon(
            Icons.directions_bus,
            size: 40,
            color: Colors.blue,
          ),
        );
      }).toList();
    });
  }

  // ✅ SEARCH
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
      appBar: AppBar(title: const Text("User Map")),

      body: Stack(
        children: [
          if (isLoadingLocation)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    userLocation ?? LatLng(10.708365, 122.563966),
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.sakayalalay",
                ),

                // ✅ USER + SEARCH MARKERS
                MarkerLayer(
                  markers: [
                    if (userLocation != null)
                      Marker(
                        point: userLocation!,
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.person_pin_circle,
                          size: 50,
                          color: Colors.green,
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

                // ✅ LIVE PAO MARKERS
                StreamBuilder<List<Marker>>(
                  stream: getLivePaoMarkers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    return MarkerLayer(markers: snapshot.data!);
                  },
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

      bottomNavigationBar: BottomNav(currentIndex: 2),
    );
  }
}
