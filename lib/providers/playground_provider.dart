import 'package:flutter/material.dart';
import '../models/positioned_widget.dart';
import '../models/widget.dart' as app_widget;
import 'dart:math' as math;

class PlaygroundProvider extends ChangeNotifier {
  final List<PositionedWidget> _widgets = [];
  bool _isDragging = false;
  String? _draggedWidgetId;
  final double _gridSize = 20.0;

  List<PositionedWidget> get widgets => List.unmodifiable(_widgets);
  bool get isDragging => _isDragging;
  String? get draggedWidgetId => _draggedWidgetId;

  void setDragging(bool value, {String? widgetId}) {
    _isDragging = value;
    _draggedWidgetId = value ? widgetId : null;
    notifyListeners();
  }

  void addWidget(app_widget.Widget widget, {app_widget.Position? position}) {
    debugPrint('=== Adding new widget to PlaygroundProvider ===');
    debugPrint('Widget ID: ${widget.id}');
    debugPrint(
      'Initial pin config: ${widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    // Generate a unique instance ID by combining the widget ID with a timestamp
    final instanceId = '${widget.id}_${DateTime.now().microsecondsSinceEpoch}';
    debugPrint('Generated instance ID: $instanceId');

    final newWidget = PositionedWidget(
      id: instanceId,
      widget: widget,
      position: position ?? app_widget.Position(x: 0, y: 0),
    );

    debugPrint(
      'New widget pin config: ${newWidget.widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    _widgets.add(newWidget);
    notifyListeners();
  }

  void removeWidget(String widgetId) {
    _widgets.removeWhere((w) => w.id == widgetId);
    notifyListeners();
  }

  void updateWidgetPosition(String id, Offset position) {
    debugPrint('=== Updating widget position in PlaygroundProvider ===');
    debugPrint('Widget ID: $id');
    debugPrint('New position: $position');

    final index = _widgets.indexWhere((w) => w.id == id);
    if (index != -1) {
      debugPrint('Found widget at index $index');

      // Create a new widget instance with updated position
      _widgets[index] = _widgets[index].copyWith(
        position: app_widget.Position(x: position.dx, y: position.dy),
      );

      debugPrint('Updated position to (${position.dx}, ${position.dy})');
      notifyListeners();
    } else {
      debugPrint('Error: Widget with ID $id not found');
    }
  }

  void updateWidget(PositionedWidget widget) {
    debugPrint('=== Updating widget in PlaygroundProvider ===');
    debugPrint('Widget ID: ${widget.id}');
    debugPrint('Position: x=${widget.position.x}, y=${widget.position.y}');
    debugPrint(
      'Current pin config: ${widget.widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    final index = _widgets.indexWhere((w) => w.id == widget.id);
    if (index != -1) {
      debugPrint('Found widget at index $index');
      debugPrint(
        'Existing widget pin config: ${_widgets[index].widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );

      // Create a new widget instance while preserving all properties
      _widgets[index] = PositionedWidget(
        id: widget.id,
        widget: widget.widget, // Keep the entire widget object intact
        position: widget.position,
        configuration: widget.configuration,
      );

      debugPrint(
        'After update pin config: ${_widgets[index].widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );
      notifyListeners();
    } else {
      debugPrint('Error: Widget with ID ${widget.id} not found');
    }
  }

  Offset snapToGrid(Offset position) {
    final x = (position.dx / _gridSize).round() * _gridSize;
    final y = (position.dy / _gridSize).round() * _gridSize;
    return Offset(x, y);
  }

  void updateWidgetConfiguration(
    String id,
    Map<String, dynamic> configuration,
  ) {
    final index = _widgets.indexWhere((widget) => widget.id == id);
    if (index != -1) {
      _widgets[index] = _widgets[index].copyWith(configuration: configuration);
      notifyListeners();
    }
  }

  void loadWidgets(List<Map<String, dynamic>> widgetList) {
    _widgets.clear();
    for (final widgetData in widgetList) {
      try {
        final widget = app_widget.Widget.fromJson(widgetData);
        final position = app_widget.Position.fromJson(
          (widgetData['position'] as Map<String, dynamic>?) ?? {'x': 0, 'y': 0},
        );

        final positionedWidget = PositionedWidget(
          id: widgetData['_id'], // Use the database ID
          widget: widget,
          position: position,
          configuration:
              widgetData['configuration'] as Map<String, dynamic>? ?? {},
        );

        _widgets.add(positionedWidget);
      } catch (e) {
        debugPrint('Error loading widget: $e');
      }
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> getWidgetList() {
    return _widgets
        .map(
          (w) => {
            'widget_id': w.widget.id,
            'name': w.widget.name,
            'image': w.widget.image,
            'pinRequired': w.widget.pinRequired,
            'pinConfig': w.widget.pinConfig,
            'position': w.position.toJson(),
            'configuration': w.configuration,
          },
        )
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {'widgets': _widgets.map((w) => w.toJson()).toList()};
  }

  void updateWidgetPinConfig(
    String widgetId,
    List<app_widget.PinConfig> newPinConfig,
  ) {
    debugPrint('=== Updating widget pin config in PlaygroundProvider ===');
    debugPrint('Widget ID: $widgetId');
    debugPrint(
      'New pin config: ${newPinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    final index = _widgets.indexWhere((w) => w.id == widgetId);
    if (index != -1) {
      final currentWidget = _widgets[index];
      debugPrint('Found widget at index $index');
      debugPrint(
        'Current pin config: ${currentWidget.widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );

      // Create updated widget with new pin configuration
      final updatedWidget = currentWidget.copyWith(
        widget: currentWidget.widget.copyWith(pinConfig: newPinConfig),
      );

      debugPrint(
        'Updated widget pin config: ${updatedWidget.widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );

      _widgets[index] = updatedWidget;
      notifyListeners();
    } else {
      debugPrint('Error: Widget with ID $widgetId not found');
    }
  }
}
