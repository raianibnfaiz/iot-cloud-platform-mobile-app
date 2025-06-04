import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../models/template.dart';
import 'package:wifi_scan/wifi_scan.dart';

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

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
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
      // Create a JSON-like string with all the configuration data
      String configData = 'CONFIG:'
          'TEMPLATE_NAME:${widget.template.templateName},'
          'TEMPLATE_ID:${widget.template.templateId},'
          'WIFI_SSID:${widget.wifiNetwork.ssid},'
          'WIFI_PASSWORD:${widget.wifiPassword},'
          'DEVICE_ID:${widget.deviceId}';

      // Send the configuration data
      connection!.output.add(Uint8List.fromList(configData.codeUnits));
      await connection!.output.allSent;

      debugPrint("Sent configuration data to ESP32: $configData");

      // Optional: Send individual commands for easier parsing on ESP32 side
      await Future.delayed(const Duration(milliseconds: 100));

      List<String> commands = [
        'TEMPLATE_NAME:${widget.template.templateName}',
        'TEMPLATE_ID:${widget.template.templateId}',
        'WIFI_SSID:${widget.wifiNetwork.ssid}',
        'WIFI_PASSWORD:${widget.wifiPassword}',
        'DEVICE_ID:${widget.deviceId}',
        'CONFIG_END'
      ];

      for (String command in commands) {
        connection!.output.add(Uint8List.fromList(command.codeUnits));
        await connection!.output.allSent;
        await Future.delayed(const Duration(milliseconds: 50));
        debugPrint("Sent: $command");
      }

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
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Template Name',
              widget.template.templateName,
              Icons.dashboard_outlined,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              'Template ID',
              widget.template.templateId,
              Icons.fingerprint,
            ),
            const SizedBox(height: 24),

            // WiFi Information
            const Text(
              'WiFi Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Network Name',
              widget.wifiNetwork.ssid,
              Icons.wifi,
            ),
            const SizedBox(height: 12),
            _buildPasswordCard(
              'Password',
              widget.wifiPassword,
              Icons.lock,
            ),
            const SizedBox(height: 24),

            // Device Information
            const Text(
              'Device Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
                  ? Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _disconnectDevice,
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text('Disconnect Device'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
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
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
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
                    label: const Text('Resend Configuration'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
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
                ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard(String title, String value, IconData icon) {
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showPassword ? value : '••••••••',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
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
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}