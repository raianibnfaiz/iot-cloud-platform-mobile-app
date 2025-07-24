import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class BrandNewPreviewPage extends StatefulWidget {
  final String templateId;
  final String templateName;
  const BrandNewPreviewPage({Key? key, required this.templateId, required this.templateName}) : super(key: key);

  @override
  State<BrandNewPreviewPage> createState() => _BrandNewPreviewPageState();
}

class _BrandNewPreviewPageState extends State<BrandNewPreviewPage> {
  bool _isLoading = true;
  String? _error;
  List<_WidgetInfo> _usedWidgets = [];

  @override
  void initState() {
    super.initState();
    _fetchTemplateDetails();
  }

  Future<void> _fetchTemplateDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiService = APIService();
      final token = await apiService.getServerToken();
      if (token == null) throw Exception('No auth token found');
      final baseUrl = APIService.baseUrl;
      final url = '$baseUrl/users/templates/${widget.templateId}';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch template: ${response.statusCode}');
      }
      final data = json.decode(response.body);
      final template = data['template'];
      final widgetList = template['widget_list'] as List<dynamic>;
      final List<_WidgetInfo> usedWidgets = [];
      for (final w in widgetList) {
        final pinConfigs = w['pinConfig'] as List<dynamic>;
        final usedPins = pinConfigs.where((p) => p['is_used'] == true).toList();
        if (usedPins.isNotEmpty) {
          usedWidgets.add(_WidgetInfo(
            name: w['widget_name'] ?? w['widget_id']['name'] ?? 'Unknown',
            pins: usedPins.map((p) => _PinInfo(
              pinName: p['pin_name'] ?? 'Pin',
              value: p['value'] ?? 0,
            )).toList(),
          ));
        }
      }
      setState(() {
        _usedWidgets = usedWidgets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand New Preview'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
                ? Text('Error: $_error', style: const TextStyle(color: Colors.red))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'This is the brand new preview page!',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Template Name:',
                        style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.templateName,
                        style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 32),
                      if (_usedWidgets.isEmpty)
                        const Text('No used widgets found.'),
                      for (final w in _usedWidgets)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final pin in w.pins)
                                    Row(
                                      children: [
                                        Text(
                                          pin.pinName,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Value: ${pin.value}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: pin.value == 1 ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.w600,
                                          ),
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
    );
  }
}

class _WidgetInfo {
  final String name;
  final List<_PinInfo> pins;
  _WidgetInfo({required this.name, required this.pins});
}

class _PinInfo {
  final String pinName;
  final int value;
  _PinInfo({required this.pinName, required this.value});
} 