import 'widget.dart' as app_widget;
import 'virtual_pin.dart';
import 'package:flutter/foundation.dart';

class PinConfig {
  final int virtualPin;
  final int value;
  final String id;

  PinConfig({required this.virtualPin, required this.value, required this.id});

  factory PinConfig.fromJson(Map<String, dynamic> json) {
    // Get ID from either 'id' or '_id' field, generate one if empty
    String id = json['id'] as String? ?? json['_id'] as String? ?? '';
    if (id.isEmpty) {
      id = 'pin_${DateTime.now().millisecondsSinceEpoch}_${json['virtualPin'] ?? 0}';
    }
    
    return PinConfig(
      virtualPin: json['virtualPin'] as int? ?? 0,
      value: json['value'] as int? ?? 0,
      id: id,
    );
  }

  Map<String, dynamic> toJson() {
    return {'virtualPin': virtualPin, 'value': value, 'id': id};
  }
}

class Position {
  final double x;
  final double y;

  Position({required this.x, required this.y});

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }
}

class TemplateWidget {
  final String widgetId;
  final String name;
  final String image;
  final int pinRequired;
  final List<PinConfig> pinConfig;
  final String id;
  final Position? position;
  final Map<String, dynamic>? configuration;

  TemplateWidget({
    required this.widgetId,
    required this.name,
    required this.image,
    required this.pinRequired,
    required this.pinConfig,
    required this.id,
    this.position,
    this.configuration,
  });

  factory TemplateWidget.fromJson(Map<String, dynamic> json) {
    // Get widget_id, ensuring it's never empty
    String widgetId = '';
    String name = json['name'] as String? ?? 'Unknown Widget';
    String image = json['image'] as String? ?? '';
    int pinRequired = json['pinRequired'] as int? ?? 0;
    
    if (json['widget_id'] != null) {
      if (json['widget_id'] is Map) {
        final widgetIdObj = json['widget_id'] as Map<String, dynamic>;
        widgetId = widgetIdObj['_id']?.toString() ?? '';
        // If name, image, pinRequired are in the widget_id object, use them
        name = widgetIdObj['name']?.toString() ?? name;
        image = widgetIdObj['image']?.toString() ?? image;
        pinRequired = int.tryParse(widgetIdObj['pinRequired']?.toString() ?? '0') ?? pinRequired;
      } else {
        widgetId = json['widget_id'].toString();
      }
    }
    
    // If widget_id is null or empty, generate a new one
    if (widgetId.isEmpty || widgetId == "null") {
      debugPrint('Generating new widget ID for widget with name: $name');
      widgetId = 'widget_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    // Get ID, ensuring it's never empty
    String id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    if (id.isEmpty) {
      id = 'template_widget_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    // Parse pin configs with better error handling
    List<PinConfig> pinConfigs = [];
    if (json['pinConfig'] != null && json['pinConfig'] is List) {
      try {
        for (var pinJson in json['pinConfig']) {
          if (pinJson is String) {
            // Generate a valid ID if the pin ID is just a string
            final pinId = pinJson.isEmpty ? 'pin_${DateTime.now().millisecondsSinceEpoch}' : pinJson;
            pinConfigs.add(PinConfig(virtualPin: 0, value: 0, id: pinId));
          } else if (pinJson is Map<String, dynamic>) {
            // Extract pin_id and value from the pin config
            int virtualPin = 0;
            int value = 0;
            
            if (pinJson.containsKey('pin_id')) {
              virtualPin = int.tryParse(pinJson['pin_id'].toString()) ?? 0;
            } else if (pinJson.containsKey('virtualPin')) {
              virtualPin = int.tryParse(pinJson['virtualPin'].toString()) ?? 0;
            }
            
            if (pinJson.containsKey('value')) {
              value = int.tryParse(pinJson['value'].toString()) ?? 0;
            }
            
            // Ensure the pin has a valid ID
            String pinId = pinJson['id']?.toString() ?? pinJson['_id']?.toString() ?? '';
            if (pinId.isEmpty) {
              pinId = 'pin_${DateTime.now().millisecondsSinceEpoch}_$virtualPin';
            }
            
            pinConfigs.add(PinConfig(
              virtualPin: virtualPin,
              value: value,
              id: pinId,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error parsing pin configs: $e');
      }
    }
    
    return TemplateWidget(
      widgetId: widgetId,
      name: name,
      image: image,
      pinRequired: pinRequired,
      pinConfig: pinConfigs,
      id: id,
      position:
          json['position'] != null
              ? Position.fromJson(json['position'] as Map<String, dynamic>)
              : Position(x: 0, y: 0), // Always provide a default position
      configuration: json['configuration'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'widget_id': widgetId,
      'name': name,
      'image': image,
      'pinRequired': pinRequired,
      'pinConfig': pinConfig.map((p) => p.toJson()).toList(),
      'id': id,
      'position': position?.toJson() ?? {'x': 0.0, 'y': 0.0},
      'configuration': configuration,
    };
  }

  // Convert template PinConfig to widget PinConfig
  List<app_widget.PinConfig> toWidgetPinConfig() {
    return pinConfig
        .map(
          (pin) => app_widget.PinConfig(
            virtualPin: pin.virtualPin,
            value: pin.value,
            id: pin.id,
          ),
        )
        .toList();
  }
}

class Template {
  final String id;
  final String templateName;
  final String templateId;
  final List<TemplateWidget> widgetList;
  final List<VirtualPin> virtual_pins;

  Template({
    required this.id,
    required this.templateName,
    required this.templateId,
    required this.widgetList,
    required this.virtual_pins,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Template && other.templateId == templateId;
  }

  @override
  int get hashCode => templateId.hashCode;

  factory Template.fromJson(Map<String, dynamic> json) {
    try {
      // Explicitly create a properly typed List<VirtualPin>
      final List<VirtualPin> virtualPins = [];
      
      // Process virtual pins with better error handling
      if (json['virtual_pins'] != null && json['virtual_pins'] is List) {
        for (var pinJson in json['virtual_pins']) {
          try {
            if (pinJson is Map<String, dynamic>) {
              // Try to create a VirtualPin from the JSON
              virtualPins.add(VirtualPin.fromJson(pinJson));
            }
          } catch (e) {
            debugPrint('Error parsing individual virtual pin: $e');
            // Add a default VirtualPin if parsing fails
            virtualPins.add(VirtualPin(
              id: '',
              pin_id: 0,
              pin_name: 'Error Pin',
              value: 0,
            ));
          }
        }
      }
      
      // Explicitly create a properly typed List<TemplateWidget>
      final List<TemplateWidget> templateWidgets = [];
      
      // Process widget list with better error handling
      if (json['widget_list'] != null && json['widget_list'] is List) {
        for (var widgetJson in json['widget_list']) {
          try {
            final position = widgetJson['position'] as Map<String, dynamic>?;
            
            String widgetId = '';
            String name = widgetJson['name']?.toString() ?? '';
            String image = widgetJson['image']?.toString() ?? '';
            int pinRequired = int.tryParse(widgetJson['pinRequired']?.toString() ?? '0') ?? 0;

            // Handle widget_id being null, Map, or String
            if (widgetJson['widget_id'] != null) {
              if (widgetJson['widget_id'] is Map) {
                final widgetIdObj = widgetJson['widget_id'] as Map<String, dynamic>;
                widgetId = widgetIdObj['_id']?.toString() ?? '';
                name = widgetIdObj['name']?.toString() ?? name;
                image = widgetIdObj['image']?.toString() ?? image;
                pinRequired = int.tryParse(widgetIdObj['pinRequired']?.toString() ?? '0') ?? pinRequired;
              } else {
                widgetId = widgetJson['widget_id']?.toString() ?? '';
              }
            }

            // Generate a widget ID if it's empty or null
            if (widgetId.isEmpty || widgetId == "null") {
              debugPrint('Generating widget ID for widget with name: $name');
              widgetId = 'widget_${DateTime.now().millisecondsSinceEpoch}';
            }

            // Create a list of PinConfig objects
            final List<PinConfig> pinConfigs = [];
            if (widgetJson['pinConfig'] != null && widgetJson['pinConfig'] is List) {
              for (var pinJson in widgetJson['pinConfig']) {
                try {
                  if (pinJson is String) {
                    // Generate a valid ID if the pin ID is just a string
                    final pinId = pinJson.isEmpty ? 'pin_${DateTime.now().millisecondsSinceEpoch}_${pinConfigs.length}' : pinJson;
                    pinConfigs.add(PinConfig(virtualPin: 0, value: 0, id: pinId));
                  } else if (pinJson is Map<String, dynamic>) {
                    // Extract pin_id and value from the pin config
                    int virtualPin = 0;
                    int value = 0;
                    
                    if (pinJson.containsKey('pin_id')) {
                      virtualPin = int.tryParse(pinJson['pin_id'].toString()) ?? 0;
                    } else if (pinJson.containsKey('virtualPin')) {
                      virtualPin = int.tryParse(pinJson['virtualPin'].toString()) ?? 0;
                    }
                    
                    if (pinJson.containsKey('value')) {
                      value = int.tryParse(pinJson['value'].toString()) ?? 0;
                    }
                    
                    // Ensure the pin has a valid ID
                    String pinId = pinJson['id']?.toString() ?? pinJson['_id']?.toString() ?? '';
                    if (pinId.isEmpty) {
                      pinId = 'pin_${DateTime.now().millisecondsSinceEpoch}_$virtualPin';
                    }
                    
                    pinConfigs.add(PinConfig(
                      virtualPin: virtualPin,
                      value: value,
                      id: pinId,
                    ));
                  }
                } catch (e) {
                  debugPrint('Error parsing pin config: $e');
                  // Add a pin with a generated ID
                  pinConfigs.add(PinConfig(
                    virtualPin: 0, 
                    value: 0, 
                    id: 'pin_${DateTime.now().millisecondsSinceEpoch}_${pinConfigs.length}'
                  ));
                }
              }
            }

            // Generate an ID if it's empty
            String id = widgetJson['id']?.toString() ?? widgetJson['_id']?.toString() ?? '';
            if (id.isEmpty) {
              id = 'template_widget_${DateTime.now().millisecondsSinceEpoch}';
            }

            templateWidgets.add(TemplateWidget(
              widgetId: widgetId,
              name: name,
              image: image,
              pinRequired: pinRequired,
              pinConfig: pinConfigs,
              id: id,
              position: position != null
                  ? Position(
                      x: double.tryParse(position['x']?.toString() ?? '0') ?? 0,
                      y: double.tryParse(position['y']?.toString() ?? '0') ?? 0,
                    )
                  : Position(x: 0, y: 0),
              configuration: widgetJson['configuration'] as Map<String, dynamic>?,
            ));
          } catch (error) {
            debugPrint('Error parsing widget: $error');
            // Skip adding invalid widgets instead of adding a minimal one
            continue;
          }
        }
      }
      
      return Template(
        id: json['_id'] as String? ?? '',
        templateName: json['template_name'] as String? ?? '',
        templateId: json['template_id'] as String? ?? '',
        widgetList: templateWidgets,
        virtual_pins: virtualPins,
      );
    } catch (error) {
      debugPrint('Error parsing template: $error');
      // Return a minimal valid template
      return Template(
        id: '',
        templateName: 'Error Template',
        templateId: '',
        widgetList: [],
        virtual_pins: [],
      );
    }
  }

  Map<String, dynamic> toJson() {
    try {
      return {
        '_id': id,
        'template_name': templateName,
        'template_id': templateId,
        'widget_list': widgetList.map((w) => w.toJson()).toList(),
        'virtual_pins': virtual_pins.map((p) => p.toJson()).toList(),
      };
    } catch (e) {
      debugPrint('Error serializing template: $e');
      // Return a minimal valid JSON if serialization fails
      return {
        '_id': id,
        'template_name': templateName,
        'template_id': templateId,
        'widget_list': [],
        'virtual_pins': [],
      };
    }
  }
}
