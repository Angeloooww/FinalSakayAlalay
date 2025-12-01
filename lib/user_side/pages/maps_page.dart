import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // ✅ SEARCH SUGGESTIONS
  List<Map<String, dynamic>> searchSuggestions = [];
  bool showSuggestions = false;
  final FocusNode _searchFocusNode = FocusNode();

  // ✅ DIRECTIONS
  List<LatLng> routePoints = [];
  bool isLoadingRoute = false;
  String? routeDistance;
  String? routeDuration;

  @override
  void initState() {
    _mapController = MapController();
    getUserLiveLocation();
    
    // Listen to search input changes
    _searchController.addListener(() {
      if (_searchController.text.length >= 3) {
        fetchSearchSuggestions(_searchController.text);
      } else {
        setState(() {
          searchSuggestions = [];
          showSuggestions = false;
        });
      }
    });
    
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  // ✅ FETCH SEARCH SUGGESTIONS
  Future<void> fetchSearchSuggestions(String query) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=$query, Iloilo City"
      "&format=json&limit=5",
    );

    try {
      final response = await http.get(url, headers: {
        "User-Agent": "sakay-alalay-app",
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;

        setState(() {
          searchSuggestions = data.map((item) {
            return {
              "display_name": item["display_name"],
              "lat": double.parse(item["lat"]),
              "lon": double.parse(item["lon"]),
            };
          }).toList();
          showSuggestions = searchSuggestions.isNotEmpty;
        });
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
    }
  }

  // ✅ SELECT SUGGESTION
  void selectSuggestion(Map<String, dynamic> suggestion) {
    setState(() {
      searchedLocation = LatLng(suggestion["lat"], suggestion["lon"]);
      _searchController.text = suggestion["display_name"];
      showSuggestions = false;
      searchSuggestions = [];
    });

    _searchFocusNode.unfocus();
    _mapController.move(searchedLocation!, 17);
    getDirections();
  }

  // ✅ SEARCH LOCATION
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

  // ✅ GET DIRECTIONS (OSRM Routing)
  Future<void> getDirections() async {
    if (userLocation == null || searchedLocation == null) return;

    setState(() {
      isLoadingRoute = true;
      routePoints = [];
    });

    final url = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/"
      "${userLocation!.longitude},${userLocation!.latitude};"
      "${searchedLocation!.longitude},${searchedLocation!.latitude}"
      "?overview=full&geometries=geojson",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["routes"] != null && data["routes"].isNotEmpty) {
          final route = data["routes"][0];
          final coords = route["geometry"]["coordinates"] as List;

          setState(() {
            routePoints = coords
                .map((coord) => LatLng(coord[1], coord[0]))
                .toList();

            // Extract distance and duration
            routeDistance = (route["distance"] / 1000).toStringAsFixed(2);
            routeDuration = (route["duration"] / 60).toStringAsFixed(0);
          });

          // Fit bounds to show entire route
          _fitRouteBounds();
        }
      }
    } catch (e) {
      print("Error getting directions: $e");
    } finally {
      setState(() => isLoadingRoute = false);
    }
  }

  // ✅ FIT MAP TO SHOW ENTIRE ROUTE
  void _fitRouteBounds() {
    if (routePoints.isEmpty) return;

    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (var point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  // ✅ CLEAR DIRECTIONS
  void clearDirections() {
    setState(() {
      searchedLocation = null;
      routePoints = [];
      routeDistance = null;
      routeDuration = null;
      searchSuggestions = [];
      showSuggestions = false;
      _searchController.clear();
    });

    if (userLocation != null) {
      _mapController.move(userLocation!, 17);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Image.asset(
                'assets/images/removed.png',
                height: 42,
                width: 42,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "User Map",
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
        actions: [
          if (searchedLocation != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: clearDirections,
              tooltip: "Clear directions",
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
                initialCenter: userLocation ?? LatLng(10.708365, 122.563966),
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.sakayalalay",
                ),

                // ✅ ROUTE LINE
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: Colors.blueAccent,
                        strokeWidth: 5.0,
                      ),
                    ],
                  ),

                // ✅ USER + SEARCH MARKERS
                MarkerLayer(
                  markers: [
                    // ✅ USER LOCATION MARKER WITH GLOWING BLUE PIN
                    if (userLocation != null)
                      Marker(
                        point: userLocation!,
                        width: 60,
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glowing effect layers
                            Icon(
                              Icons.location_on,
                              size: 60,
                              color: const Color(0xFF2B5F9E).withOpacity(0.3),
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF2B5F9E).withOpacity(0.8),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            Icon(
                              Icons.location_on,
                              size: 60,
                              color: const Color(0xFF2B5F9E).withOpacity(0.5),
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF2B5F9E).withOpacity(0.6),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            // Main location pin
                            Icon(
                              Icons.location_on,
                              size: 60,
                              color: const Color(0xFF2B5F9E),
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF2B5F9E).withOpacity(0.9),
                                  blurRadius: 8,
                                ),
                                Shadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            // Transparent person icon (cut-out effect)
                            const Positioned(
                              top: 8,
                              child: Icon(
                                Icons.person,
                                size: 28,
                                color: Colors.transparent,
                              ),
                            ),
                          ],
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

          // ✅ SEARCH BAR WITH SUGGESTIONS
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF2B5F9E),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            hintText: "Search places...",
                            hintStyle: TextStyle(
                              color: Colors.black45,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (value) async {
                            if (value.trim().isNotEmpty && searchSuggestions.isNotEmpty) {
                              selectSuggestion(searchSuggestions.first);
                            }
                          },
                        ),
                      ),
                      if (isLoadingRoute)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: Color(0xFF2B5F9E),
                          ),
                          onPressed: () {
                            if (_searchController.text.trim().isNotEmpty && searchSuggestions.isNotEmpty) {
                              selectSuggestion(searchSuggestions.first);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),

                // ✅ SUGGESTIONS DROPDOWN
                if (showSuggestions && searchSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: searchSuggestions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = searchSuggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.blue),
                          title: Text(
                            suggestion["display_name"],
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => selectSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ✅ ROUTE INFO CARD
          if (routeDistance != null && routeDuration != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.straighten, color: Colors.blue),
                        const SizedBox(height: 4),
                        Text(
                          "$routeDistance km",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text("Distance", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.access_time, color: Colors.blue),
                        const SizedBox(height: 4),
                        Text(
                          "$routeDuration min",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text("Duration", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNav(currentIndex: 2),
    );
  }
}