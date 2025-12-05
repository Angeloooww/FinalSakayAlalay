import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  PaoModel? _nearestPao; // ✅ Track nearest jeepney

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _requestLocationPermission();
    _loadAvailableRoutes();
  }

  Future<void> _loadAvailableRoutes() async {
    try {
      final routes = await _firestoreService.getActiveRoutes();
      setState(() {
        _availableRoutes = routes;
        _isLoadingRoutes = false;
      });
    } catch (e) {
      print("Error loading routes: $e");
      setState(() {
        _isLoadingRoutes = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load routes: $e")),
        );
      }
    }
  }

  void _listenToPaosByRoute(String routeName) {
    _firestoreService.getActivePaosByRoute(routeName).listen((paos) {
      setState(() {
        _filteredPaos = paos;
        _nearestPao = _findNearestPao(paos); // ✅ Find nearest jeepney
      });

      // ✅ Auto-zoom to nearest jeepney when route is selected
      if (_nearestPao != null && currentLocation != null) {
        _zoomToNearestPao();
      }
    }, onError: (error) {
      print("Error fetching PAOs: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading jeepneys: $error")),
        );
      }
    });
  }

  // ✅ NEW: Find the nearest PAO to user's current location
  PaoModel? _findNearestPao(List<PaoModel> paos) {
    if (currentLocation == null || paos.isEmpty) return null;

    PaoModel? nearest;
    double minDistance = double.infinity;

    for (var pao in paos) {
      if (pao.lat == null || pao.lng == null) continue;

      double distance = Geolocator.distanceBetween(
        currentLocation!.latitude,
        currentLocation!.longitude,
        pao.lat!,
        pao.lng!,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = pao;
      }
    }

    return nearest;
  }

  // ✅ NEW: Zoom to show both user and nearest PAO
  void _zoomToNearestPao() {
    if (_nearestPao == null || currentLocation == null) return;
    if (_nearestPao!.lat == null || _nearestPao!.lng == null) return;

    final paoLocation = LatLng(_nearestPao!.lat!, _nearestPao!.lng!);

    // Calculate bounds to show both markers
    final bounds = LatLngBounds(
      LatLng(
        currentLocation!.latitude < paoLocation.latitude
            ? currentLocation!.latitude
            : paoLocation.latitude,
        currentLocation!.longitude < paoLocation.longitude
            ? currentLocation!.longitude
            : paoLocation.longitude,
      ),
      LatLng(
        currentLocation!.latitude > paoLocation.latitude
            ? currentLocation!.latitude
            : paoLocation.latitude,
        currentLocation!.longitude > paoLocation.longitude
            ? currentLocation!.longitude
            : paoLocation.longitude,
      ),
    );

    // Fit bounds with padding
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(100),
      ),
    );
  }

  // ✅ NEW: Calculate distance in human-readable format
  String _getDistanceText(PaoModel pao) {
    if (currentLocation == null || pao.lat == null || pao.lng == null) {
      return "Unknown distance";
    }

    double distanceInMeters = Geolocator.distanceBetween(
      currentLocation!.latitude,
      currentLocation!.longitude,
      pao.lat!,
      pao.lng!,
    );

    if (distanceInMeters < 1000) {
      return "${distanceInMeters.round()}m away";
    } else {
      return "${(distanceInMeters / 1000).toStringAsFixed(1)}km away";
    }
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

      _mapController.move(currentLocation!, 15);
    } catch (e) {
      setState(() {
        locationStatus = "Failed to get location: $e";
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _sendPwdFlag(PaoModel pao) async {
  if (currentLocation == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Unable to get your location"),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please login to send notifications"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Get passenger details from Firestore
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();

    String passengerName = "Unknown";
    if (userDoc.exists) {
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      passengerName = "${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}".trim();
      if (passengerName.isEmpty) passengerName = "Unknown";
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.accessible, color: Color(0xFF2B5F9E)),
            SizedBox(width: 8),
            Text("PWD Notification"),
          ],
        ),
        content: Text(
          "Send a notification to ${pao.lastName}, ${pao.middleName} that a PWD passenger is waiting at your current location?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5F9E),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Send Notification",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ✅ Create notification with passenger details
    await FirebaseFirestore.instance.collection("pwd_notifications").add({
      "paoId": pao.id,
      "passengerId": currentUser.uid,
      "passengerName": passengerName, // ✅ Added passenger name
      "passengerEmail": currentUser.email ?? "Unknown",
      "latitude": currentLocation!.latitude,
      "longitude": currentLocation!.longitude,
      "routeName": pao.routeName,
      "paoName": "${pao.lastName}, ${pao.middleName}",
      "status": "pending", // ✅ Can be: pending, accepted, declined
      "timestamp": FieldValue.serverTimestamp(),
      "isRead": false,
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "PWD notification sent to ${pao.lastName}, ${pao.middleName}",
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "OK",
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  } catch (e) {
    print("Error sending PWD flag: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send notification: $e"),
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
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.sakayalalay",
                ),
                MarkerLayer(
                  markers: [
                    // ✅ User location marker
                    Marker(
                      point: currentLocation!,
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.my_location,
                        size: 40,
                        color: Color(0xFF2B5F9E),
                      ),
                    ),
                    // ✅ PAO markers at their ACTUAL locations
                    ..._filteredPaos.where((pao) => pao.lat != null && pao.lng != null).map((pao) {
                      final isNearest = _nearestPao?.id == pao.id;
                      return Marker(
                        point: LatLng(pao.lat!, pao.lng!), // ✅ Use PAO's real location
                        width: isNearest ? 70 : 50,
                        height: isNearest ? 70 : 50,
                        child: GestureDetector(
                          onTap: () {
                            _showPaoDetails(pao);
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: isNearest ? Colors.orange : Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: isNearest ? 3 : 2,
                                  ),
                                  boxShadow: isNearest
                                      ? [
                                          BoxShadow(
                                            color: Colors.orange.withOpacity(0.5),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  Icons.directions_bus,
                                  color: Colors.white,
                                  size: isNearest ? 32 : 24,
                                ),
                              ),
                              if (isNearest)
                                Positioned(
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'NEAREST',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
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
                            
                            // ✅ Show nearest jeepney info
                            if (_selectedRoute != null && _nearestPao != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.near_me,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Nearest: ${_nearestPao!.lastName}, ${_nearestPao!.middleName}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              _getDistanceText(_nearestPao!),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                        ),
                                        onPressed: () {
                                          _showPaoDetails(_nearestPao!);
                                        },
                                        child: const Text(
                                          "View",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            
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
                                                    _nearestPao = null;
                                                  });
                                                  _listenToPaosByRoute(
                                                      route);
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
                                  minimumSize:
                                      const Size(double.infinity, 50),
                                  disabledBackgroundColor:
                                      Colors.grey[300],
                                ),
                                onPressed: _selectedRoute == null
                                    ? null
                                    : () {
                                        if (_nearestPao != null) {
                                          _zoomToNearestPao();
                                        }
                                        
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
              _buildInfoRow("Distance", _getDistanceText(pao)),
              _buildInfoRow(
                  "Status", pao.isVerified ? "Verified" : "Unverified"),
              const SizedBox(height: 20),
              
              // PWD FLAG BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.accessible, color: Colors.white),
                  label: const Text(
                    "PWD Waiting Here",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _sendPwdFlag(pao),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Track button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5F9E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (pao.lat != null && pao.lng != null) {
                      _mapController.move(
                        LatLng(pao.lat!, pao.lng!),
                        17,
                      );
                    }
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