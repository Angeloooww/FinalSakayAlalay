import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../navigation/nav_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MapController _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  LatLng? currentLocation;
  bool isLoadingLocation = true;
  String locationStatus = "Getting your location...";

  String? _selectedRoute;

  final List<String> _iloiloCityRoutes = [
    'Ungka-CPU-Jaro-City Proper',
    'Ungka-Festive Walk-City Proper',
    'SM City-Festive Walk-City Proper',
    'Tagbak-Buntatala-City Proper',
    'La Paz-Ticud-City Proper',
    'Villa Plaza-Calumpang-City Proper',
    'Mandurriao-Festive Walk-City Proper',
    'Molo-Baluarte-City Proper',
    'Lapuz-Barrio Obrero-City Proper',
    'Mohon-Arevalo-City Proper',
    'Parola-Infante-SM City',
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        locationStatus = "Location services are disabled";
        isLoadingLocation = false;
      });
      return;
    }

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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Image.asset(
                'assets/images/removed.png',
                height: 40,
                width: 40,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Home",
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
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
                  Text(locationStatus),
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
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.sakayalalay",
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.location_on,
                        size: 60,
                        color: Color(0xFF2B5F9E),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          // ✅ DRAGGABLE PANEL WITH BACKGROUND COLOR SELECTION
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.15,
            minChildSize: 0.15,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(blurRadius: 10, color: Colors.black26)
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),

                            GestureDetector(
                              onTap: () {
                                _sheetController.animateTo(
                                  0.6,
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              },
                              child: Container(
                                height: 6,
                                width: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            const Text(
                              "Find a Route",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              height: 300,
                              child: ListView.builder(
                                itemCount: _iloiloCityRoutes.length,
                                itemBuilder: (context, index) {
                                  final route =
                                      _iloiloCityRoutes[index];
                                  final isSelected =
                                      _selectedRoute == route;

                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF2B5F9E)
                                              .withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(
                                          Icons.directions_bus),
                                      title: Text(
                                        route,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedRoute = route;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF2B5F9E),
                                  minimumSize: const Size(
                                      double.infinity, 50),
                                ),
                                onPressed: _selectedRoute == null
                                    ? null
                                    : () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                "Selected Route: $_selectedRoute"),
                                          ),
                                        );

                                        _sheetController.animateTo(
                                          0.15,
                                          duration: const Duration(
                                              milliseconds: 300),
                                          curve: Curves.easeIn,
                                        );
                                      },
                                child: const Text(
                                  "Confirm Route",
                                  style:
                                      TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),

      bottomNavigationBar: BottomNav(currentIndex: 0),
    );
  }
}
