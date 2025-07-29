import 'package:bjit_iot_platform_mobile_app/screens/templates/template_playground_screen.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../../models/template.dart';
import '../../models/widget.dart' as app_widget;
import '../../models/positioned_widget.dart';
import '../../providers/playground_provider.dart';
import '../../providers/widget_provider.dart';
import '../../widgets/base_screen.dart';
import '../../components/draggable_widget_component.dart';
import '../../services/toast_service.dart';
import '../../services/api_service.dart';
import '../../services/mqtt_service.dart';
import '../dashboard/dashboard_screen.dart';
import 'package:provider/provider.dart';

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
            message: 'Received update: ${decodedMessage['data']}', textStyle: TextStyle(fontSize: 14, color: Colors.white),
          );
        } catch (e) {
          ToastService.info(
            context,
            message: 'Received: $message', textStyle: TextStyle(fontSize: 14, color: Colors.white),
          );
        }
      }
    });
  }

  // Update the handler to accept index
  Future<void> _handleWidgetInteraction(PositionedWidget positionedWidget, bool newValue, int index) async {
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

      // Use the correct index for widgetId
      final widgetId = 'template_${positionedWidget.widget.id}_$index';
      final data = {
        "token": token,
        "V_P": virtualPin,
        "data": newValue,
        "templateId": widget.template.templateId,
        "widgetId": widgetId,
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      };

      // Publish the data using MQTT
      await _mqttService.publishModuleData(
        widget.template.templateId,
        positionedWidget.id,
        data,
      );

      if (mounted) {

        print('Sent value: $newValue to pin $virtualPin');
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

  // Check if a widget is a switch widget based on its image field
  bool _isSwitchWidget(String image) {
    try {
      if (image.startsWith('{')) {
        final config = jsonDecode(image);
        final isSwitch = config is Map &&
            config.containsKey('type') &&
            (config['type'].toString().toLowerCase().contains('switch') ||
                config['type'].toString().toLowerCase().contains('button') ||
                config['name'].toString().toLowerCase().contains('switch'));
        debugPrint('Checking if widget is switch: $isSwitch (${config['name'] ?? 'unknown'})');
        return isSwitch;
      }
    } catch (e) {
      debugPrint('Error checking if widget is switch: $e');
    }
    return false;
  }

  // Create modified pin config with initial value set to 1 for switches
  List<app_widget.PinConfig> _createModifiedPinConfig(List<dynamic> originalPinConfig, bool isSwitch) {
    return originalPinConfig.map((pinData) {
      if (isSwitch) {
        // For switch widgets, set initial value to 1 (ON)
        return app_widget.PinConfig(
          id: pinData.id,
          virtualPin: pinData.virtualPin,
          value: pinData.value, // Override to 1 for switches
        );
      } else {
        // For non-switch widgets, keep original value
        return app_widget.PinConfig(
          id: pinData.id,
          virtualPin: pinData.virtualPin,
          value: pinData.value,
        );
      }
    }).toList();
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

  Future<void> _saveTemplateToBackend() async {
    final apiService = APIService();
    final token = await apiService.getServerToken();
    if (token == null) {
      ToastService.error(context, message: 'No auth token found');
      return;
    }

    final playgroundProvider = context.read<PlaygroundProvider>();

    // Build widget_list for the request
    final widgetList = playgroundProvider.widgets.map((positionedWidget) {
      return {
        "widget_id": positionedWidget.widget.id,
        "instance_id": positionedWidget.id, // Use the unique id from PlaygroundProvider
        "pinConfig": positionedWidget.widget.pinConfig.map((pin) => {
          "pin_id": pin.virtualPin,
          "pin_name": "Virtual Pin ${pin.virtualPin}",
          "value": pin.value,
          // You may want to store min_value, max_value, is_used, _id if available in your model
          "min_value": 0, // Replace with actual value if available
          "max_value": 255, // Replace with actual value if available
          "is_used": true, // Replace with actual value if available
          "_id": pin.id,
        }).toList(),
        "position": {
          "x": positionedWidget.position.x,
          "y": positionedWidget.position.y,
        },
      };
    }).toList();

    final body = {
      "template_name": widget.template.templateName,
      "widget_list": widgetList,
    };

    final url = "${APIService.baseUrl}/users/templates/${widget.template.templateId}";
    final response = await http.put(
      Uri.parse(url),
      headers: {
        "accept": "application/json",
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      ToastService.success(context, message: "Template saved successfully!");
    } else {
      ToastService.error(context, message: "Failed to save template: ${response.body}");
    }

  }

  void _updateWidgetPosition(String widgetId, Offset newPosition) {
    debugPrint('=== Updating widget position ===');
    debugPrint('Widget ID: $widgetId');
    debugPrint('New position: $newPosition');

    final playgroundProvider = context.read<PlaygroundProvider>();
    final existingWidget = playgroundProvider.widgets.firstWhere(
          (w) => w.id == widgetId, // Use exact instance ID match
      orElse: () {
        debugPrint('Widget not found by exact ID: $widgetId');
        // Fallback to base widget ID if needed
        return playgroundProvider.widgets.firstWhere(
              (w) => w.widget.id == widgetId,
          orElse: () {
            debugPrint('Widget not found by widget.id either: $widgetId');
            return playgroundProvider.widgets.first;
          },
        );
      },
    );

    debugPrint(
      'Found widget. Current pin configs: ${existingWidget.widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    // Create updated widget with new position while preserving ALL existing properties
    final updatedWidget = existingWidget.copyWith(
      position: app_widget.Position(x: newPosition.dx, y: newPosition.dy),
      // Preserve ALL widget properties including pin configuration
      widget: existingWidget.widget,
    );

    debugPrint(
      'After position update pin configs: ${updatedWidget.widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    playgroundProvider.updateWidget(updatedWidget);
  }

  void _loadExistingWidgets() {
    final playgroundProvider = context.read<PlaygroundProvider>();
    final widgetProvider = context.read<WidgetProvider>();

    debugPrint('Loading widgets from template: ${widget.template.templateId}');
    debugPrint(
      'Template widget list count: ${widget.template.widgetList.length}',
    );

    // Load each widget from the template's widget list
    for (final templateWidget in widget.template.widgetList) {
      debugPrint(
        'Loading widget ${templateWidget.name} with position: x=${templateWidget.position?.x}, y=${templateWidget.position?.y}',
      );
      debugPrint(
        'Widget ID: ${templateWidget.widgetId}, Template Widget ID: ${templateWidget.id}',
      );
      debugPrint(
        'Pin config for widget: ${templateWidget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );

      // Ensure we have a valid widget ID
      String widgetId = templateWidget.widgetId;
      if (widgetId.isEmpty || widgetId == "null") {
        widgetId =
        'widget_${DateTime.now().millisecondsSinceEpoch}_${templateWidget.name.replaceAll(' ', '_')}';
        debugPrint('Generated new widget ID: $widgetId for empty or null ID');
      }

      // Find the corresponding widget from the widget provider
      final matchingWidget = widgetProvider.widgets.firstWhere(
            (w) => w.id == widgetId,
        orElse: () {
          debugPrint('Creating fallback widget for: $widgetId');
          return app_widget.Widget(
            id: widgetId,
            name: templateWidget.name,
            image: templateWidget.image,
            pinRequired: templateWidget.pinRequired,
            pinConfig:
            templateWidget.toWidgetPinConfig().map((pin) {
              // Ensure pin IDs are not empty
              if (pin.id.isEmpty) {
                return pin.copyWith(
                  id:
                  'pin_${DateTime.now().millisecondsSinceEpoch}_${pin.virtualPin}',
                );
              }
              return pin;
            }).toList(),
            position: app_widget.Position(
              x: templateWidget.position?.x ?? 20.0,
              y: templateWidget.position?.y ?? 20.0,
            ),
            configuration: templateWidget.configuration,
          );
        },
      );

      // Create a new widget with the template's pin configuration
      final widgetWithPins = matchingWidget.copyWith(
        pinConfig:
        templateWidget.toWidgetPinConfig().map((pin) {
          // Ensure pin IDs are not empty
          if (pin.id.isEmpty) {
            return pin.copyWith(
              id:
              'pin_${DateTime.now().millisecondsSinceEpoch}_${pin.virtualPin}',
            );
          }
          return pin;
        }).toList(),
      );

      debugPrint('Adding widget to playground: ${widgetWithPins.name}');
      debugPrint(
        'Final pin config: ${widgetWithPins.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );

      // Add the widget to the playground with its saved position and pin configuration
      playgroundProvider.addWidget(
        widgetWithPins,
        position: app_widget.Position(
          x: templateWidget.position?.x ?? 20.0,
          y: templateWidget.position?.y ?? 20.0,
        ),
      );

      // Update used pins set
      //_usedPins.addAll(templateWidget.pinConfig.map((pin) => pin.virtualPin));
    }
  }

  @override
  Widget build(BuildContext context) {

    debugPrint('Building TemplatePreviewScreen for template: ${widget.template.templateName}');
    debugPrint('Template widget list count: ${widget.template.widgetList.length}');

    // Print detailed widget position data
    debugPrint('========================================');
    debugPrint('WIDGET POSITION DATA AFTER BLUETOOTH CONNECTION:');
    debugPrint('Template ID: ${widget.template.templateId}');
    debugPrint('Template Name: ${widget.template.templateName}');
    debugPrint('Total Widgets: ${widget.template.widgetList.length}');
    debugPrint('========================================');

    for (int i = 0; i < widget.template.widgetList.length; i++) {
      final templateWidget = widget.template.widgetList[i];
      debugPrint('Widget ${i + 1}:');
      debugPrint('  - ID: ${templateWidget.id}');
      debugPrint('  - Name: ${templateWidget.name}');
      debugPrint('  - Widget ID: ${templateWidget.widgetId}');
      debugPrint('  - Position: (${templateWidget.position?.x ?? 0}, ${templateWidget.position?.y ?? 0})');
      debugPrint('  - Pin Required: ${templateWidget.pinRequired}');
      debugPrint('  - Pin Config Count: ${templateWidget.pinConfig.length}');

      // Print pin configuration details
      for (int j = 0; j < templateWidget.pinConfig.length; j++) {
        final pin = templateWidget.pinConfig[j];
        debugPrint('    Pin ${j + 1}:');
        debugPrint('      - Virtual Pin: ${pin.virtualPin}');
        debugPrint('      - Value: ${pin.value}');
        debugPrint('      - ID: ${pin.id}');
      }

      // Print configuration if available
      if (templateWidget.configuration != null && templateWidget.configuration!.isNotEmpty) {
        debugPrint('  - Configuration: ${templateWidget.configuration}');
      }

      debugPrint('  - Image: ${templateWidget.image.substring(0, min(100, templateWidget.image.length))}...');
      debugPrint('----------------------------------------');
    }

    return WillPopScope(
        onWillPop: () async {

          ToastService.success(context, message: "Template saved. Returning to Playground.");

          // Save the template to the backend

          return true;
        },
    child: BaseScreen(
      title: "Preview ${widget.template.templateName}",
      actions: [
        IconButton(
          icon: const Icon(Icons.dashboard_outlined),
          tooltip: 'Go to Dashboard',
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => DashboardScreen()),
                  (route) => false,
            );
          },
        ),
      ],
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
          ...widget.template.widgetList.asMap().entries.map((entry) {
    final index = entry.key;
    final templateWidget = entry.value;
    debugPrint('Creating widget from template: ${templateWidget.name}');
    debugPrint('Widget image: ${templateWidget.image.substring(0, min(50, templateWidget.image.length))}...');
    debugPrint('Pin config: ${templateWidget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}');

    final is3D = _is3DWidget(templateWidget.image);
    final isSwitch = _isSwitchWidget(templateWidget.image);
    debugPrint('Is 3D widget: $is3D');
    debugPrint('Is Switch widget: $isSwitch');

    // Create modified pin config with initial value set to 1 for switches
    final modifiedPinConfig = _createModifiedPinConfig(templateWidget.pinConfig, isSwitch);
    debugPrint('Modified pin config: ${modifiedPinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}');

    final widget = app_widget.Widget(
      id: templateWidget.widgetId,
      name: templateWidget.name,
      image: templateWidget.image,
      pinRequired: templateWidget.pinRequired,
      pinConfig: modifiedPinConfig,
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
        onValueChanged: (newValue) => _handleWidgetInteraction(positionedWidget, newValue, index),
      ),
    );
  }),
        ],
      ),
    )
    );
  }
}

// Helper function to get the minimum of two integers
int min(int a, int b) => a < b ? a : b;


