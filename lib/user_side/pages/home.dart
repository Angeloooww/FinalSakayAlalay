import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../navigation/nav_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_page.dart';
import '../services/firestore_service.dart';
import '../../models/pao_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MapController _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final FirestoreService _firestoreService = FirestoreService();

  LatLng? currentLocation;
  bool isLoadingLocation = true;
  String locationStatus = "Getting your location...";

  String? _selectedRoute;
  List<String> _availableRoutes = [];
  List<PaoModel> _filteredPaos = [];
  bool _isLoadingRoutes = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _requestLocationPermission();
    _loadAvailableRoutes();
  }

    // Load all available routes from Firestore - ONLY routes with active PAOs
  Future<void> _loadAvailableRoutes() async {
    try {
      final routes = await _firestoreService.getActiveRoutes(); // ✅ CHANGED
      setState(() {
        _availableRoutes = routes;
        _isLoadingRoutes = false;
      });
    } catch (e) {
      print("Error loading routes: $e");
      setState(() {
        _isLoadingRoutes = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load routes: $e")),
      );
    }
  }

  // Listen to ACTIVE PAOs for selected route
  void _listenToPaosByRoute(String routeName) {
    _firestoreService.getActivePaosByRoute(routeName).listen((paos) { // ✅ CHANGED
      setState(() {
        _filteredPaos = paos;
      });
    }, onError: (error) {
      print("Error fetching PAOs: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading jeepneys: $error")),
      );
    });
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
                    // User's current location marker
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
                    // PAO/Jeepney markers for selected route
                    ..._filteredPaos.map((pao) {
                      // If PAO has location data, show them on map
                      // You'll need to add latitude/longitude fields to your PaoModel
                      // For now, this is a placeholder
                      return Marker(
                        point: currentLocation!, // Replace with pao.location when available
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () {
                            _showPaoDetails(pao);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.directions_bus,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),

          // DRAGGABLE PANEL WITH ROUTE FILTERING
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

                            // Drag handle
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

                            // Show selected route info
                            if (_selectedRoute != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B5F9E)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Route: $_selectedRoute",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          "${_filteredPaos.length} Available",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 10),

                            // Routes list
                            _isLoadingRoutes
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : _availableRoutes.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Text(
                                              "No routes available"),
                                        ),
                                      )
                                    : SizedBox(
                                        height: 300,
                                        child: ListView.builder(
                                          itemCount:
                                              _availableRoutes.length,
                                          itemBuilder: (context, index) {
                                            final route =
                                                _availableRoutes[index];
                                            final isSelected =
                                                _selectedRoute == route;

                                            return Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFF2B5F9E)
                                                        .withOpacity(0.15)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10),
                                                border: isSelected
                                                    ? Border.all(
                                                        color: const Color(
                                                            0xFF2B5F9E),
                                                        width: 2)
                                                    : null,
                                              ),
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.directions_bus,
                                                  color: isSelected
                                                      ? const Color(
                                                          0xFF2B5F9E)
                                                      : Colors.grey,
                                                ),
                                                title: Text(
                                                  route,
                                                  style: TextStyle(
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                                trailing: isSelected
                                                    ? const Icon(
                                                        Icons.check_circle,
                                                        color: Color(
                                                            0xFF2B5F9E),
                                                      )
                                                    : null,
                                                onTap: () {
                                                  setState(() {
                                                    _selectedRoute = route;
                                                    _filteredPaos = [];
                                                  });
                                                  _listenToPaosByRoute(
                                                      route);
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                            // Confirm button
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF2B5F9E),
                                  minimumSize:
                                      const Size(double.infinity, 50),
                                  disabledBackgroundColor:
                                      Colors.grey[300],
                                ),
                                onPressed: _selectedRoute == null
                                    ? null
                                    : () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Tracking $_selectedRoute - ${_filteredPaos.length} jeepney(s) available",
                                            ),
                                            backgroundColor:
                                                Colors.green,
                                          ),
                                        );

                                        _sheetController.animateTo(
                                          0.15,
                                          duration: const Duration(
                                              milliseconds: 300),
                                          curve: Curves.easeIn,
                                        );
                                      },
                                child: Text(
                                  _selectedRoute == null
                                      ? "Select a Route"
                                      : "Confirm Route (${_filteredPaos.length} available)",
                                  style: TextStyle(
                                    color: _selectedRoute == null
                                        ? Colors.grey[600]
                                        : Colors.white,
                                  ),
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

  // Show PAO details in a bottom sheet
  void _showPaoDetails(PaoModel pao) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus,
                      size: 32, color: Color(0xFF2B5F9E)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "${pao.lastName}, ${pao.middleName}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (pao.isVerified)
                    const Icon(Icons.verified, color: Colors.green),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow("Position", pao.position),
              _buildInfoRow("Route", pao.routeName),
              _buildInfoRow(
                  "Status", pao.isVerified ? "Verified" : "Unverified"),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5F9E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Add booking or tracking functionality here
                  },
                  child: const Text(
                    "Track This Jeepney",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }
}