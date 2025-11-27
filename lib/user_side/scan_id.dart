import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanPWDPage extends StatefulWidget {
  const ScanPWDPage({super.key});

  @override
  State<ScanPWDPage> createState() => _ScanPWDPageState();
}

class _ScanPWDPageState extends State<ScanPWDPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _scanned = false;
  String? scannedData;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.request();

    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission required.')),
      );
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Scan Your PWD ID"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (_scanned) return;

                    final List<Barcode> barcodes = capture.barcodes;
                    final Barcode barcode = barcodes.first;

                    setState(() {
                      _scanned = true;
                      scannedData = barcode.rawValue ?? "Unknown data";
                    });
                  },
                ),

                // Overlay frame for scanning
                Center(
                  child: Container(
                    width: 260,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.yellow.shade700,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                if (_scanned)
                  Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "PWD ID Detected!",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            scannedData ?? "",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _scanned = false;
                                scannedData = null;
                              });
                              cameraController.start();
                            },
                            child: const Text("Scan Again"),
                          )
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
