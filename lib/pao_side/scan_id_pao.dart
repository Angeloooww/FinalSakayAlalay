import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanPAOIdPage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const ScanPAOIdPage({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<ScanPAOIdPage> createState() => _ScanPAOIdPageState();
}

class _ScanPAOIdPageState extends State<ScanPAOIdPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _scanned = false;
  bool _isSaving = false;
  String? scannedData;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.request();

    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required.')),
        );
      }
    }
  }

  Future<void> _savePAOIdData() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Update PAO document with scanned ID data
      await FirebaseFirestore.instance
          .collection('pao')
          .doc(widget.userId)
          .update({
        'paoIdScanned': scannedData,
        'idVerificationStatus': 'pending',
        'idScannedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PAO ID verified! Your account is pending approval.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Sign out user and redirect to login
        await FirebaseAuth.instance.signOut();
        
        // Navigate back to login
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving ID data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        title: const Text("Scan Your PAO ID"),
        centerTitle: true,
        backgroundColor: const Color(0xFF2B5F9E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Instruction Text
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF2B5F9E).withOpacity(0.1),
            child: Column(
              children: [
                const Icon(
                  Icons.badge,
                  size: 48,
                  color: Color(0xFF2B5F9E),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please scan your PAO ID',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F9E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Position the barcode/QR code within the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Stack(
              children: [
                // Camera Scanner
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (_scanned) return;

                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    
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
                    width: 280,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF2B5F9E),
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Corner markers
                Center(
                  child: SizedBox(
                    width: 280,
                    height: 180,
                    child: Stack(
                      children: [
                        // Top-left corner
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2B5F9E),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        // Top-right corner
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2B5F9E),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        // Bottom-left corner
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2B5F9E),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        // Bottom-right corner
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2B5F9E),
                              borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Scanned overlay
                if (_scanned)
                  Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(40),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 64,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "PAO ID Detected!",
                              style: TextStyle(
                                color: Color(0xFF2B5F9E),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                scannedData ?? "No data",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () {
                                          setState(() {
                                            _scanned = false;
                                            scannedData = null;
                                          });
                                          cameraController.start();
                                        },
                                  child: const Text("Scan Again"),
                                ),
                                ElevatedButton(
                                  onPressed: _isSaving ? null : _savePAOIdData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2B5F9E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Text("Confirm"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Bottom instruction
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Your account will be reviewed by an administrator',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}