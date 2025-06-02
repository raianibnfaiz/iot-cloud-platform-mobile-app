import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../models/template.dart';
import '../../models/widget.dart' as app_widget;
import '../../models/positioned_widget.dart';
import '../../widgets/base_screen.dart';
import '../../components/draggable_widget_component.dart';
import '../../services/toast_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/mqtt_service.dart';

class TemplatePreviewScreen extends StatefulWidget {
  final Template template;

  const TemplatePreviewScreen({Key? key, required this.template})
    : super(key: key);

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  bool _isConnected = false;
  bool _isConnecting = true;
  final APIService _apiService = APIService();
  final MQTTService _mqttService = MQTTService();
  StreamSubscription? _mqttSubscription;

  @override
  void initState() {
    super.initState();
    _connectToTemplate();
    _setupMQTTListener();
  }

  @override
  void dispose() {
    _mqttSubscription?.cancel();
    _mqttService.disconnect();
    super.dispose();
  }

  void _setupMQTTListener() {
    _mqttSubscription = _mqttService.messageStream.listen((data) {
      if (mounted) {
        final message = data['message'];
        try {
          final decodedMessage = json.decode(message);
          ToastService.info(
            context,
            message: 'Received update: ${decodedMessage['data']}',
          );
        } catch (e) {
          ToastService.info(
            context,
            message: 'Received: $message',
          );
        }
      }
    });
  }

  Future<void> _handleWidgetInteraction(PositionedWidget positionedWidget, bool newValue) async {
    try {
      // Get the auth token
      final token = await _apiService.getServerToken();
      
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Get the virtual pin number from the widget's pin config
      final virtualPin = positionedWidget.widget.pinConfig.isNotEmpty 
          ? positionedWidget.widget.pinConfig.first.virtualPin 
          : 0;

      // Prepare the data to send in the required format
      final data = {
        "token": token,
        "V_P": virtualPin,
        "data": newValue ? 1 : 0,
        "tmp": "S"  // S for Switch
      };

      // Publish the data using MQTT
      await _mqttService.publishModuleData(
        widget.template.templateId,
        positionedWidget.id,
        data,
      );

      if (mounted) {
        ToastService.success(
          context,
          message: 'Sent value: ${newValue ? 1 : 0} to pin $virtualPin',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastService.error(
          context,
          message: 'Failed to send value: $e',
        );
      }
    }
  }

  Future<void> _connectToTemplate() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      debugPrint('Connecting to template: ${widget.template.templateId}');
      
      // Get the auth token
      final authService = APIService();
      final token = await authService.getServerToken();
      debugPrint('Token: $token');
      
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final url = '${APIService.baseUrl}/users/connectme?template_id=${widget.template.templateId}';
      debugPrint('Connecting to template: $url');
      // Make the API call to connect to the template
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Connect response status: ${response.statusCode}');
      debugPrint('Connect response body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
        
        if (mounted) {
          ToastService.success(
            context, 
            message: 'Successfully connected to template',
          );
        }
      } else {
        throw Exception('Failed to connect to template: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error connecting to template: $e');
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      
      if (mounted) {
        ToastService.error(
          context, 
          message: 'Failed to connect to template: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  // Check if a widget is a 3D widget based on its image field
  bool _is3DWidget(String image) {
    try {
      if (image.startsWith('{')) {
        final config = jsonDecode(image);
        final is3D = config is Map && config.containsKey('type') && config['type'].toString().contains('3d');
        debugPrint('Checking if widget is 3D: $is3D (${config['name'] ?? 'unknown'})');
        return is3D;
      }
    } catch (e) {
      debugPrint('Error checking if widget is 3D: $e');
    }
    return false;
  }

  void _showWidgetDetails(BuildContext context, PositionedWidget widget) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Widget Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text('Name: ${widget.widget.name}'),
                const SizedBox(height: 8),
                Text(
                  'Position: (${widget.position.x.toStringAsFixed(2)}, ${widget.position.y.toStringAsFixed(2)})',
                ),
                if (widget.configuration.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Configuration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...widget.configuration.entries.map(
                    (entry) => Text('${entry.key}: ${entry.value}'),
                  ),
                ],
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building TemplatePreviewScreen for template: ${widget.template.templateName}');
    debugPrint('Template widget list count: ${widget.template.widgetList.length}');
    
    return BaseScreen(
      title: "Preview ${widget.template.templateName}",
      body: Stack(
        children: [
          // Connection status indicator
          if (_isConnecting)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connecting...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          
          if (!_isConnecting)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected ? Icons.check_circle : Icons.error,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          
          // Widgets
          ...widget.template.widgetList.map((templateWidget) {
            debugPrint('Creating widget from template: ${templateWidget.name}');
            debugPrint('Widget image: ${templateWidget.image.substring(0, min(50, templateWidget.image.length))}...');
            debugPrint('Pin config: ${templateWidget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}');
            
            final is3D = _is3DWidget(templateWidget.image);
            debugPrint('Is 3D widget: $is3D');
            
            final widget = app_widget.Widget(
              id: templateWidget.widgetId,
              name: templateWidget.name,
              image: templateWidget.image,
              pinRequired: templateWidget.pinRequired,
              pinConfig: templateWidget.toWidgetPinConfig(),
              position: app_widget.Position(
                x: templateWidget.position?.x ?? 20.0,
                y: templateWidget.position?.y ?? 20.0,
              ),
              configuration: templateWidget.configuration,
            );

            debugPrint('Created widget with ID: ${widget.id}');
            debugPrint('Widget pin config: ${widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}');

            final positionedWidget = PositionedWidget(
              id: templateWidget.id,
              widget: widget,
              position: app_widget.Position(
                x: templateWidget.position?.x ?? 20.0,
                y: templateWidget.position?.y ?? 20.0,
              ),
              configuration: templateWidget.configuration ?? {},
            );

            debugPrint('Created positioned widget with ID: ${positionedWidget.id}');

            return Positioned(
              left: positionedWidget.position.x,
              top: positionedWidget.position.y,
              child: DraggableWidgetComponent(
                positionedWidget: positionedWidget,
                isPreviewMode: true,
                onPositionChanged: (_) {},
                onRemove: () {},
                onTap: () => _showWidgetDetails(context, positionedWidget),
                onValueChanged: (newValue) => _handleWidgetInteraction(positionedWidget, newValue),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Helper function to get the minimum of two integers
int min(int a, int b) => a < b ? a : b;
