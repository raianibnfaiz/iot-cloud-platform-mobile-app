import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

part 'widget.g.dart';

@HiveType(typeId: 1)
class PinConfig {
  @HiveField(0)
  final int virtualPin;

  @HiveField(1)
  final int value;

  @HiveField(2)
  final String id;

  PinConfig({
    required this.virtualPin,
    required this.value,
    required this.id,
  });

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
    return {
      'virtualPin': virtualPin,
      'value': value,
      'id': id,  // Use 'id' instead of '_id' to match the API expectations
    };
  }

  PinConfig copyWith({
    int? virtualPin,
    int? value,
    String? id,
  }) {
    return PinConfig(
      virtualPin: virtualPin ?? this.virtualPin,
      value: value ?? this.value,
      id: id ?? this.id,
    );
  }
}

@HiveType(typeId: 3)
class Position {
  @HiveField(0)
  final double x;

  @HiveField(1)
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

@HiveType(typeId: 2)
class Widget {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String image;

  @HiveField(3)
  final int pinRequired;

  @HiveField(4)
  final List<PinConfig> pinConfig;

  @HiveField(5)
  final Position? position;

  @HiveField(6)
  final Map<String, dynamic>? configuration;

  Widget({
    required this.id,
    required this.name,
    required this.image,
    required this.pinRequired,
    required this.pinConfig,
    this.position,
    this.configuration,
  });

  factory Widget.fromJson(Map<String, dynamic> json) {
    // Get ID from either 'id' or '_id' field, generate one if empty
    String id = json['id'] as String? ?? json['_id'] as String? ?? '';
    if (id.isEmpty) {
      id = 'widget_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    // Parse pin config with better error handling
    List<PinConfig> pinConfigs = [];
    if (json['pinConfig'] != null) {
      try {
        pinConfigs = (json['pinConfig'] as List)
            .map((e) => e is Map<String, dynamic> 
                ? PinConfig.fromJson(e) 
                : PinConfig(virtualPin: 0, value: 0, id: 'pin_${DateTime.now().millisecondsSinceEpoch}'))
            .toList();
      } catch (e) {
        debugPrint('Error parsing pin configs: $e');
        // Create empty pin config list if parsing fails
      }
    }
    
    return Widget(
      id: id,
      name: json['name'] as String? ?? 'Unknown Widget',
      image: json['image'] as String? ?? '',
      pinRequired: json['pinRequired'] as int? ?? 0,
      pinConfig: pinConfigs,
      position:
          json['position'] != null
              ? Position.fromJson(json['position'] as Map<String, dynamic>)
              : null,
      configuration: json['configuration'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,  // Use 'id' instead of '_id' to match the API expectations
      'name': name,
      'image': image,
      'pinRequired': pinRequired,
      'pinConfig': pinConfig.map((e) => e.toJson()).toList(),
      'position': position?.toJson(),
      'configuration': configuration,
    };
  }

  Widget copyWith({
    String? id,
    String? name,
    String? image,
    int? pinRequired,
    List<PinConfig>? pinConfig,
    Position? position,
    Map<String, dynamic>? configuration,
  }) {
    return Widget(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      pinRequired: pinRequired ?? this.pinRequired,
      pinConfig: pinConfig ?? this.pinConfig,
      position: position ?? this.position,
      configuration: configuration ?? this.configuration,
    );
  }
}
