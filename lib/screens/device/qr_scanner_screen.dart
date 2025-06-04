import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../../models/template.dart';
import 'device_connection_info_screen.dart';

class QRScannerScreen extends StatefulWidget {
  final Template template;
  final WiFiAccessPoint wifiNetwork;
  final String wifiPassword;

  const QRScannerScreen({
    super.key,
    required this.template,
    required this.wifiNetwork,
    required this.wifiPassword,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _scanned = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) async {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (!_scanned) {
        setState(() {
          _scanned = true;
        });
        controller.pauseCamera();

        final deviceData = scanData.code;
        if (deviceData != null) {
          // Request Bluetooth and location permissions
          Map<Permission, PermissionStatus> statuses = await [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            Permission.locationWhenInUse,
          ].request();

          if (statuses[Permission.bluetoothScan]!.isGranted &&
              statuses[Permission.bluetoothConnect]!.isGranted &&
              statuses[Permission.locationWhenInUse]!.isGranted) {
            // Navigate to device connection info screen
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceConnectionInfoScreen(
                    template: widget.template,
                    wifiNetwork: widget.wifiNetwork,
                    wifiPassword: widget.wifiPassword,
                    deviceId: deviceData,
                  ),
                ),
              );
            }
          } else {
            // Handle permission denied case
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Required permissions not granted')),
              );
              controller.resumeCamera();
              setState(() {
                _scanned = false;
              });
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.white,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 8,
              cutOutSize: screenSize.width * 0.6,
              overlayColor: Colors.black.withOpacity(0.6),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan QR code',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Scan the QR code on your IoT device',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}