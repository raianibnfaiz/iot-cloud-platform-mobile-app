import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../models/template.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../../services/template_service.dart';
import 'qr_scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceConnectionInfoScreen extends StatefulWidget {
  final Template template;
  final WiFiAccessPoint wifiNetwork;
  final String wifiPassword;
  final String deviceId;

  const DeviceConnectionInfoScreen({
    super.key,
    required this.template,
    required this.wifiNetwork,
    required this.wifiPassword,
    required this.deviceId,
  });

  @override
  State<DeviceConnectionInfoScreen> createState() => _DeviceConnectionInfoScreenState();
}

class _DeviceConnectionInfoScreenState extends State<DeviceConnectionInfoScreen> {
  bool _showPassword = false;
  BluetoothConnection? connection;
  bool isConnected = false;
  bool isScanning = false;
  bool isConnecting = false;
  final _templateService = TemplateService();
  List<Template> _templates = [];
  Template? _selectedTemplate;
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  List<WiFiAccessPoint> _accessPoints = [];
  bool _isScanningWifi = false;
  WiFiAccessPoint? _selectedNetwork;

  // Helper function to find matching WiFiAccessPoint
  WiFiAccessPoint? _findMatchingNetwork(WiFiAccessPoint? network) {
    if (network == null) return null;
    return _accessPoints.firstWhere(
      (ap) => ap.ssid == network.ssid,
      orElse: () => network,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.template;
    _passwordController.text = widget.wifiPassword;
    _selectedNetwork = widget.wifiNetwork;
    _loadTemplates();
    _initializeWiFiScan();
  }

  @override
  void dispose() {
    connection?.dispose();
    _passwordController.dispose();
    super.dispose();
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
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load templates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeWiFiScan() async {
    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan != CanStartScan.yes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot scan for WiFi networks: ${canScan.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await _startWiFiScan();
  }

  Future<void> _startWiFiScan() async {
    setState(() {
      _isScanningWifi = true;
    });

    try {
      // Request permissions individually
      final locationStatus = await Permission.location.request();
      final nearbyWifiStatus = await Permission.nearbyWifiDevices.request();

      if (!locationStatus.isGranted || !nearbyWifiStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Required permissions not granted'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final isScanning = await WiFiScan.instance.startScan();
      if (!isScanning) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start WiFi scan'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

      if (mounted) {
        setState(() {
          _accessPoints = uniqueNetworks.values.toList();
          _isScanningWifi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanningWifi = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning WiFi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _connectToDevice() async {
    setState(() {
      isScanning = true;
      isConnecting = true;
    });

    try {
      // Start discovery to find the device
      FlutterBluetoothSerial.instance.startDiscovery().listen((r) async {
        // Check if the discovered device name matches our device ID
        if (r.device.name == widget.deviceId) {
          setState(() {
            isScanning = false;
          });

          // Cancel discovery once we find our device
          FlutterBluetoothSerial.instance.cancelDiscovery();

          try {
            // Attempt to connect to the device
            connection = await BluetoothConnection.toAddress(r.device.address);

            setState(() {
              isConnected = true;
              isConnecting = false;
            });

            debugPrint('Connected to ${widget.deviceId}');

            // Send all the configuration data to ESP32
            await _sendConfigurationData();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Device connected and configured successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }

          } catch (e) {
            setState(() {
              isConnecting = false;
            });
            debugPrint('Connection failed: $e');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Connection failed: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      });

      // Set a timeout for the discovery process
      Future.delayed(const Duration(seconds: 30), () {
        if (isScanning) {
          FlutterBluetoothSerial.instance.cancelDiscovery();
          setState(() {
            isScanning = false;
            isConnecting = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Device not found. Make sure it\'s nearby and discoverable.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      });

    } catch (e) {
      setState(() {
        isScanning = false;
        isConnecting = false;
      });

      debugPrint('Discovery failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start device discovery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendConfigurationData() async {
    if (connection == null) return;

    try {
      // Create JSON string with the specified pattern
      String configData = '''{"authToken":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6Im1vb25jc2VydTE0QGdtYWlsLmNvbSIsInVzZXJfaWQiOiJ1c3JfYTRiZmU3ODE3ZiIsImlhdCI6MTc0NzI4Nzk3MX0.z0rvXD59zTHm-gyXffQf2wXvPxQ5CaMj37v_Lc5xJy0","template_id":"${_selectedTemplate?.templateId}","VirtualPin":${_selectedTemplate?.virtual_pins.length},"WifiSSID":"${_selectedNetwork?.ssid}","WiFipassword":"${_passwordController.text}"}\n''';

      // Send the configuration data
      connection!.output.add(Uint8List.fromList(configData.codeUnits));
      await connection!.output.allSent;

      debugPrint("Sent configuration data to ESP32: $configData");

    } catch (e) {
      debugPrint('Failed to send configuration data: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _disconnectDevice() {
    if (connection != null) {
      connection!.dispose();
      setState(() {
        connection = null;
        isConnected = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device disconnected'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Connection Info'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status
            if (isConnected || isConnecting)
              Card(
                color: isConnected ? Colors.green.shade50 : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                        color: isConnected ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          isConnected
                              ? 'Connected to ${widget.deviceId}'
                              : 'Connecting to ${widget.deviceId}...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isConnected ? Colors.green.shade700 : Colors.blue.shade700,
                          ),
                        ),
                      ),
                      if (isConnected)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _disconnectDevice,
                        ),
                    ],
                  ),
                ),
              ),

            if (isConnected || isConnecting) const SizedBox(height: 24),

            // Template Information
            const Text(
              'Template Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildTemplateDropdown(),
            const SizedBox(height: 12),
            _buildInfoCard(
              'Template ID',
              _selectedTemplate?.templateId ?? '',
              Icons.fingerprint,
            ),
            const SizedBox(height: 24),

            // WiFi Information
            const Text(
              'WiFi Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildWiFiNetworkDropdown(),
            const SizedBox(height: 12),
            _buildEditablePasswordCard(
              'Password',
              _passwordController,
              Icons.lock,
            ),
            const SizedBox(height: 24),

            // Device Information
            const Text(
              'Device Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Device ID',
              widget.deviceId,
              Icons.devices,
            ),
            const SizedBox(height: 32),

            // Connect/Disconnect Button
            Center(
              child: isConnected
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _disconnectDevice,
                              icon: const Icon(Icons.bluetooth_disabled),
                              label: const Text('Disconnect'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (connection != null) {
                                  await _sendConfigurationData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Configuration resent to device'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Resend Config'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: isConnecting ? null : _connectToDevice,
                      icon: isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bluetooth_searching),
                      label: Text(isConnecting ? 'Connecting...' : 'Connect Device'),
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

  Widget _buildTemplateDropdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Template Name',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _selectedTemplate?.templateId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                items: _templates.map((Template template) {
                  return DropdownMenuItem<String>(
                    value: template.templateId,
                    child: Text(template.templateName),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    final selectedTemplate = _templates.firstWhere(
                      (t) => t.templateId == newValue,
                      orElse: () => widget.template,
                    );
                    setState(() {
                      _selectedTemplate = selectedTemplate;
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditablePasswordCard(String title, TextEditingController controller, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2196F3)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: controller,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWiFiNetworkDropdown() {
    // Find the matching network in the current list
    final currentNetwork = _findMatchingNetwork(_selectedNetwork);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Network Name',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                IconButton(
                  icon: _isScanningWifi
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _isScanningWifi ? null : _startWiFiScan,
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<WiFiAccessPoint>(
              value: currentNetwork,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              items: _accessPoints.map((WiFiAccessPoint network) {
                return DropdownMenuItem<WiFiAccessPoint>(
                  value: network,
                  child: Text(network.ssid.isNotEmpty ? network.ssid : 'Hidden Network'),
                );
              }).toList(),
              onChanged: (WiFiAccessPoint? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedNetwork = newValue;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2196F3)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (title == 'Device ID')
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () {
                  // Navigate back to QR scanner screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QRScannerScreen(
                        template: _selectedTemplate ?? widget.template,
                        wifiNetwork: widget.wifiNetwork,
                        wifiPassword: _passwordController.text,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}