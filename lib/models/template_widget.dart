// Import the correct template model
import 'template.dart';

// This class is deprecated and should not be used. Use models/template.dart instead
// This file is kept for backward compatibility but will be removed in a future update
class TemplateWidgetPosition {
  final double x;
  final double y;

  TemplateWidgetPosition({required this.x, required this.y});

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
  };

  factory TemplateWidgetPosition.fromJson(Map<String, dynamic> json) {
    return TemplateWidgetPosition(
      x: ((json['x'] ?? 0) as num).toDouble(),
      y: ((json['y'] ?? 0) as num).toDouble(),
    );
  }
}

// This class is deprecated and should not be used. Use models/template.dart instead
// This file is kept for backward compatibility but will be removed in a future update
class TemplateWidget {
  final String widgetId;
  final List<String> pinConfig;
  final TemplateWidgetPosition position;
  // Add fields to match the model in template.dart
  final String name;
  final String image;
  final int pinRequired;
  final String id;
  final Map<String, dynamic>? configuration;

  TemplateWidget({
    required this.widgetId,
    required this.pinConfig,
    required this.position,
    this.name = '',
    this.image = '',
    this.pinRequired = 0,
    this.id = '',
    this.configuration,
  });

  Map<String, dynamic> toJson() => {
    'widget_id': widgetId,
    'pinConfig': pinConfig,
    'position': position.toJson(),
    'name': name,
    'image': image,
    'pinRequired': pinRequired,
    'id': id,
    'configuration': configuration,
  };

  factory TemplateWidget.fromJson(Map<String, dynamic> json) {
    return TemplateWidget(
      widgetId: json['widget_id'] as String,
      pinConfig: (json['pinConfig'] as List? ?? []).map((e) => e.toString()).toList(),
      position: TemplateWidgetPosition.fromJson(json['position'] as Map<String, dynamic>? ?? {'x': 0, 'y': 0}),
      name: json['name'] as String? ?? '',
      image: json['image'] as String? ?? '',
      pinRequired: json['pinRequired'] as int? ?? 0,
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      configuration: json['configuration'] as Map<String, dynamic>?,
    );
  }
} 