import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../navigation/nav_bar.dart';

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  late final MapController _mapController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Maps")),

      body: Stack(
        children: [
          /// OPENSTREETMAP VIEW (free, no API key)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLocation,
              initialZoom: 16,
            ),
            children: [

              /// TILE LAYER (OpenStreetMap)
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.sakayalalay",
              ),

              /// MARKERS LAYER
              MarkerLayer(
                markers: [

                  /// USER MARKER
                  Marker(
                    point: userLocation,
                    width: 50,
                    height: 50,
                    child: Image.asset(
                      "assets/icons/user_marker.png",
                      width: 48,
                    ),
                  ),

                  /// JEEPNEY MARKERS
                  ...jeepneyLocations.map(
                    (pos) => Marker(
                      point: pos,
                      width: 50,
                      height: 50,
                      child: Image.asset(
                        "assets/icons/jeep_marker.png",
                        width: 48,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          /// SEARCH BAR OVERLAY — same UI as yours
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Robinson’s Main",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const Icon(Icons.mic, color: Colors.black54),
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
