import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../models/template.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../../services/template_service.dart';
import 'qr_scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import '../templates/template_preview_screen.dart';

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
  final _apiService = APIService();
  List<Template> _templates = [];
  Template? _selectedTemplate;
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  List<WiFiAccessPoint> _accessPoints = [];
  bool _isScanningWifi = false;
  WiFiAccessPoint? _selectedNetwork;
  List<int>? _assignedPins;
  bool _isRequestingPins = false;
  bool _hasNavigated = false;

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
    _requestVirtualPins(); // Automatically request virtual pins when screen loads
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
    try {
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
        });
      }
    } catch (e) {
      debugPrint('Error initializing WiFi scan: $e');
    }
  }

  Future<void> _startWiFiScan() async {
    setState(() {
      _isScanningWifi = true;
    });

    // Show loading spinner for 1 second
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isScanningWifi = false;
      });
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

            // Wait for response from ESP32
            String response = '';
            connection!.input!.listen((Uint8List data) {
              response = String.fromCharCodes(data);
              debugPrint('----------------------------------------');
              debugPrint('ESP32 Response Details:');
              debugPrint('Raw response: $response');
              debugPrint('Response length: ${response.length}');
             // debugPrint('Response bytes: ${data.toString()}');
              debugPrint('----------------------------------------');

              // Check if response is empty or incomplete
              if (response.trim().isEmpty) {
                debugPrint('Empty response received from ESP32');
                return;
              }

              try {
                // Try to parse the response as JSON
                final jsonResponse = json.decode(response);
                debugPrint('Parsed JSON response: $jsonResponse');
                
                // Check if the response has the expected structure with status code
                if (jsonResponse is Map<dynamic, dynamic> && jsonResponse.containsKey('status')) {
                  if (jsonResponse['status'] == "success") {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Device configured successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // Fetch the latest template data with widget positions and virtual pins
                      _templateService.getTemplate(_selectedTemplate!.templateId).then((latestTemplate) {
                        // Update template with virtual pins if available
                        if (_assignedPins != null && _assignedPins!.isNotEmpty) {
                          // Update widget positions and virtual pins in the template
                          final updatedWidgets = latestTemplate.widgetList.asMap().entries.map((entry) {
                            final widget = entry.value;
                            final index = entry.key;
                            
                            // Create new pin configuration if needed
                            List<PinConfig>? updatedPinConfig;
                            if (widget.pinConfig.isNotEmpty) {
                              updatedPinConfig = widget.pinConfig.map((pin) {
                                if (index < _assignedPins!.length) {
                                  return PinConfig(
                                    virtualPin: _assignedPins![index],
                                    value: pin.value,
                                    id: pin.id,
                                  );
                                }
                                return pin;
                              }).toList();
                            }

                            // Create updated widget with new pin configuration
                            return TemplateWidget(
                              widgetId: widget.widgetId,
                              name: widget.name,
                              image: widget.image,
                              pinRequired: widget.pinRequired,
                              pinConfig: updatedPinConfig ?? widget.pinConfig,
                              id: widget.id,
                              position: widget.position,
                              configuration: widget.configuration,
                            );
                          }).toList();

                          // Create updated template with new widget data
                          final updatedTemplate = Template(
                            id: latestTemplate.id,
                            templateName: latestTemplate.templateName,
                            templateId: latestTemplate.templateId,
                            widgetList: updatedWidgets,
                            virtual_pins: latestTemplate.virtual_pins,
                          );

                          if (!_hasNavigated && mounted) {
                            _hasNavigated = true;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TemplatePreviewScreen(
                                  template: updatedTemplate,
                                ),
                              ),
                            );
                          }
                        } else {
                          // If no virtual pins, just navigate with latest template
                          if (!_hasNavigated && mounted) {
                            _hasNavigated = true;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TemplatePreviewScreen(
                                  template: latestTemplate,
                                ),
                              ),
                            );
                          }
                        }
                      }).catchError((error) {
                        debugPrint('Error fetching latest template: $error');
                        // If fetch fails, navigate with current template
                        if (!_hasNavigated && mounted) {
                          _hasNavigated = true;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TemplatePreviewScreen(
                                template: _selectedTemplate!,
                              ),
                            ),
                          );
                        }
                      });
                    }
                  } else {
                    throw Exception(jsonResponse['message'] ?? 'Device configuration failed');
                  }
                } else {
                  // If response doesn't have expected structure, show error
                  debugPrint('Unexpected response format: $response');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid response from device'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Error parsing ESP32 response: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error processing device response: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            });

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
      // Get the auth token
      final token = await _apiService.getServerToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Create JSON string with the specified pattern
      String configData = '''{"authToken":"$token","template_id":"${_selectedTemplate?.templateId}","VirtualPin":${_assignedPins != null ? _assignedPins : []},"WifiSSID":"${_selectedNetwork?.ssid}","WiFipassword":"${_passwordController.text}"}\n''';

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

  Future<void> _requestVirtualPins() async {
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a template first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if device ID matches "4x_switches"
    if (widget.deviceId != "4x_switches") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Virtual pin request is only available for 4x_switches device'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isRequestingPins = true;
    });

    try {
      final pins = await _apiService.requestVirtualPins(
        templateId: _selectedTemplate!.templateId,
        templateName: _selectedTemplate!.templateName,
        componentName: '4x_switches',
      );

      setState(() {
        _assignedPins = pins;
        _isRequestingPins = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully assigned virtual pins: ${pins.join(", ")}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRequestingPins = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request virtual pins: $e'),
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
              child: isConnected || isConnecting
                  ? const SizedBox.shrink() // Remove Disconnect and Resend Config buttons
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
            // Replace the Row around line 807 in device_connection_info_screen.dart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(  // Add Expanded to constrain the Text widget
                  child: const Text(
                    'Network Name',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,  // Add this to handle text overflow
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,  // Reduce padding to save space
                  constraints: const BoxConstraints(),  // Minimize constraints
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
            // Fix for the DropdownButtonFormField at line 813
            DropdownButtonFormField<WiFiAccessPoint>(
              value: currentNetwork,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              isExpanded: true, // Add this to make the dropdown take full width
              items: _accessPoints.map((WiFiAccessPoint network) {
                return DropdownMenuItem<WiFiAccessPoint>(
                  value: network,
                  child: Text(
                    network.ssid.isNotEmpty ? network.ssid : 'Hidden Network',
                    overflow: TextOverflow.ellipsis, // Add text overflow handling
                  ),
                );
              }).toList(),
              onChanged: (WiFiAccessPoint? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedNetwork = newValue;
                  });
                }
              },
            )
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