import 'package:flutter/material.dart';
import 'widget.dart' as app_widget;

class PositionedWidget {
  final String id;
  final app_widget.Widget widget;
  final app_widget.Position position;
  final Map<String, dynamic> configuration;

  PositionedWidget({
    required this.id,
    required this.widget,
    required this.position,
    Map<String, dynamic>? configuration,
  }) : configuration = configuration ?? {};

  PositionedWidget copyWith({
    String? id,
    app_widget.Widget? widget,
    app_widget.Position? position,
    Map<String, dynamic>? configuration,
  }) {
    return PositionedWidget(
      id: id ?? this.id,
      widget: widget ?? this.widget,
      position: position ?? this.position,
      configuration: configuration ?? Map.from(this.configuration),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'widget_id': widget.id,
      'position': position.toJson(),
      'configuration': configuration,
    };
  }
}
