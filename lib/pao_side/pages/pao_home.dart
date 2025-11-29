import 'dart:convert';
import 'package:finalsakay/pao_side/navigation/pao_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class PAOHomePage extends StatefulWidget {
  const PAOHomePage({super.key});

  @override
  State<PAOHomePage> createState() => _MapsPageState();
}

class _MapsPageState extends State<PAOHomePage> {
  late final MapController _mapController;

  LatLng? searchedLocation; // NEW: will hold search result

  final TextEditingController _searchController = TextEditingController();

  late final LatLng userLocation = LatLng(10.708365, 122.563966);

  final List<LatLng> jeepneyLocations = const [
    LatLng(10.708985, 122.562500),
    LatLng(10.708100, 122.565100),
    LatLng(10.709300, 122.566900),
  ];

  @override
  void initState() {
    _mapController = MapController();
    super.initState();
  }

  /// ---------------------------------------------------------
  /// SEARCH USING OPENSTREETMAP NOMINATIM (FREE)
  /// ---------------------------------------------------------
  Future<void> searchPlace(String query) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=$query, Iloilo City"
      "&format=json&limit=1"
    );

    final response = await http.get(url, headers: {
      "User-Agent": "sakay-alalay-app"
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data.isNotEmpty) {
        final double lat = double.parse(data[0]["lat"]);
        final double lon = double.parse(data[0]["lon"]);

        setState(() {
          searchedLocation = LatLng(lat, lon);
        });

        // MOVE MAP
        _mapController.move(searchedLocation!, 17);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Maps")),

      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLocation,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.sakayalalay",
              ),

              // -------------------------------------------
              // ALL MARKERS (user, jeep, search result)
              // -------------------------------------------
              MarkerLayer(
                markers: [
                 // SEARCH RESULT MARKER (OPTIONAL)
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

          // ---------------------------------------------------
          // SEARCH BAR (NOW WORKING)
          // ---------------------------------------------------
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
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search places in Iloilo City...",
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.search),
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
