import 'package:bjit_iot_platform_mobile_app/screens/device/qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/toast_service.dart';
import '../../services/template_service.dart';
import '../../models/template.dart';

class ConnectDeviceScreen extends StatefulWidget {
  const ConnectDeviceScreen({super.key});

  @override
  State<ConnectDeviceScreen> createState() => _ConnectDeviceScreenState();
}

class _ConnectDeviceScreenState extends State<ConnectDeviceScreen> {
  final _templateService = TemplateService();
  final _passwordController = TextEditingController();
  List<Template> _templates = [];
  List<WiFiAccessPoint> _accessPoints = [];
  Template? _selectedTemplate;
  WiFiAccessPoint? _selectedNetwork;
  bool _isLoading = true;
  bool _isScanning = false;
  String? _error;
  String _password = '';

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _initializeWiFiScan();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeWiFiScan() async {
    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan != CanStartScan.yes) {
      setState(() {
        _error = 'Cannot scan for WiFi networks: ${canScan.toString()}';
      });
      return;
    }

    await _startWiFiScan();
  }

  Future<void> _startWiFiScan() async {
    final permissions = await [
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    if (!permissions.values.every((status) => status.isGranted)) {
      setState(() {
        _error = 'Required permissions not granted';
      });
      return;
    }

    final canStartScan = await WiFiScan.instance.canStartScan();
    if (canStartScan != CanStartScan.yes) {
      setState(() {
        _error = 'Cannot start scan: $canStartScan';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _error = null;
    });

    final isScanning = await WiFiScan.instance.startScan();
    if (!isScanning) {
      setState(() {
        _error = 'Failed to start scan';
        _isScanning = false;
      });
      return;
    }

    // Wait for scan results
    await Future.delayed(const Duration(seconds: 2));
    final results = await WiFiScan.instance.getScannedResults();
    
    // Create a map to store unique SSIDs with their strongest signal
    final Map<String, WiFiAccessPoint> uniqueNetworks = {};
    for (var accessPoint in results) {
      final ssid = accessPoint.ssid.isNotEmpty ? accessPoint.ssid : 'Hidden Network';
      if (!uniqueNetworks.containsKey(ssid) ||
          accessPoint.level > uniqueNetworks[ssid]!.level) {
        uniqueNetworks[ssid] = accessPoint;
      }
    }

    setState(() {
      _accessPoints = uniqueNetworks.values.toList();
      _isScanning = false;
    });
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await _templateService.getTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Device'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadTemplates();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _templates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'No templates found',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.devices,
                            size: 80,
                            color: Color(0xFF2196F3),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Connect Your Device',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Select a template and configure WiFi settings',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Template Selection
                          DropdownButtonFormField<Template>(
                            decoration: const InputDecoration(
                              labelText: 'Select Template',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            value: _selectedTemplate,
                            items: _templates.map((template) {
                              return DropdownMenuItem(
                                value: template,
                                child: Text(template.templateName),
                              );
                            }).toList(),
                            onChanged: (Template? value) {
                              setState(() {
                                _selectedTemplate = value;
                              });
                            },
                          ),
                          const SizedBox(height: 24),

                          // WiFi Network Selection
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'WiFi Network',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: _isScanning ? null : _startWiFiScan,
                                icon: _isScanning
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<WiFiAccessPoint>(
                            decoration: const InputDecoration(
                              labelText: 'Select WiFi Network',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            value: _selectedNetwork,
                            items: _accessPoints.map((ap) {
                              final ssid = ap.ssid.isNotEmpty ? ap.ssid : 'Hidden Network';
                              final secured = ap.capabilities.contains('WPA') ||
                                  ap.capabilities.contains('WEP');
                              return DropdownMenuItem(
                                value: ap,
                                child: Row(
                                  children: [
                                    Icon(
                                      secured ? Icons.lock : Icons.lock_open,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(ssid),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (WiFiAccessPoint? value) {
                              setState(() {
                                _selectedNetwork = value;
                              });
                            },
                          ),
                          const SizedBox(height: 24),

                          // WiFi Password
                          if (_selectedNetwork != null &&
                              (_selectedNetwork!.capabilities.contains('WPA') ||
                                  _selectedNetwork!.capabilities.contains('WEP')))
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'WiFi Password',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              obscureText: true,
                              onChanged: (value) {
                                setState(() {
                                  _password = value;
                                });
                              },
                            ),
                          const SizedBox(height: 32),

                          // Connect Button
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: (_selectedTemplate == null ||
                                      _selectedNetwork == null ||
                                      (_selectedNetwork!.capabilities.contains('WPA') &&
                                          _password.isEmpty))
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => QRScannerScreen(
                                            template: _selectedTemplate!,
                                            wifiNetwork: _selectedNetwork!,
                                            wifiPassword: _password,
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.bluetooth_searching),
                              label: const Text('Connect Device'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
} 