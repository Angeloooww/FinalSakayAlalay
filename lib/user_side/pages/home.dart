import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../navigation/nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MapController _mapController;
  LatLng? currentLocation;
  bool isLoadingLocation = true;
  String locationStatus = "Getting your location...";

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        locationStatus = "Location services are disabled";
        isLoadingLocation = false;
      });
      return;
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          locationStatus = "Location permission denied";
          isLoadingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        locationStatus = "Location permission permanently denied";
        isLoadingLocation = false;
      });
      return;
    }

    // Get current location
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        isLoadingLocation = false;
        locationStatus = "Location found";
      });

      // Move map to current location
      _mapController.move(currentLocation!, 17);
    } catch (e) {
      setState(() {
        locationStatus = "Failed to get location: $e";
        isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (isLoadingLocation)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    locationStatus,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          else if (currentLocation == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locationStatus,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _requestLocationPermission,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: currentLocation!,
                initialZoom: 17,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.sakayalalay",
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
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
                  ],
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: BottomNav(currentIndex: 0),
    );
  }
}