import 'package:flutter/material.dart';
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

            // Connect Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement device connection logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connecting device...'),
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