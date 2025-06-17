import 'package:bjit_iot_platform_mobile_app/screens/device/qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
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
  bool _showPassword = false;
  StreamSubscription? _templateUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _initializeWiFiScan();
    // Listen for template updates
    _templateUpdateSubscription = _templateService.onTemplateUpdate.listen((updatedTemplate) {
      _updateTemplate(updatedTemplate);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _templateUpdateSubscription?.cancel();
    super.dispose();
  }

  void _updateTemplate(Template updatedTemplate) {
    setState(() {
      final index = _templates.indexWhere(
        (t) => t.templateId == updatedTemplate.templateId,
      );
      if (index != -1) {
        _templates[index] = updatedTemplate;
      }
    });
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
      _isScanning = true;
    });

    // Show loading spinner for 1 second
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
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

  Future<void> _createTemplate() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Template'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Template Name',
              hintText: 'Enter template name',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a template name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, nameController.text);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ).then((templateName) async {
      if (templateName != null) {
        try {
          setState(() {
            _isLoading = true;
          });

          final newTemplate = await _templateService.createTemplate(templateName);
          await _loadTemplates();

          if (mounted) {
            setState(() {
              _isLoading = false;
              _selectedTemplate = newTemplate;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Template created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create template: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Device'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            position: PopupMenuPosition.under,
            offset: const Offset(0, 10),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'create_template',
                child: Row(
                  children: [
                    Icon(Icons.dashboard_outlined),
                    SizedBox(width: 8),
                    Text('Create Template'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'create_template') {
                _createTemplate();
              }
            },
          ),
        ],
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: const Icon(
                          Icons.devices,
                          size: 70,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: const Text(
                          'Connect Your Device',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
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
                      const Text(
                        'Appoint Template',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_templates.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'No templates available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _createTemplate,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Create Template'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
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
                          decoration: InputDecoration(
                            labelText: 'WiFi Password',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
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
                          obscureText: !_showPassword,
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
                          icon: const Icon(Icons.qr_code),
                          label: const Text('Scan QR Code'),
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