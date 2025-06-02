import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/positioned_widget.dart';
import '../models/widget.dart' as app_widget;
import '../providers/playground_provider.dart';
import 'interactive_3d_widget.dart';

class DraggableWidgetComponent extends StatefulWidget {
  final PositionedWidget positionedWidget;
  final bool isPreviewMode;
  final Function(app_widget.Position) onPositionChanged;
  final VoidCallback onRemove;
  final VoidCallback? onTap;
  final Function(bool)? onValueChanged;

  const DraggableWidgetComponent({
    Key? key,
    required this.positionedWidget,
    required this.isPreviewMode,
    required this.onPositionChanged,
    required this.onRemove,
    this.onTap,
    this.onValueChanged,
  }) : super(key: key);

  @override
  State<DraggableWidgetComponent> createState() =>
      _DraggableWidgetComponentState();
}

class _DraggableWidgetComponentState extends State<DraggableWidgetComponent> {
  bool _isDragging = false;
  bool _is3DWidget = false;
  bool _switchValue = false;
  Offset _dragStartPosition = Offset.zero;
  Offset _widgetStartPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _checkIf3DWidget();
    // Initialize switch value from pin configuration if available
    if (widget.positionedWidget.widget.pinConfig.isNotEmpty) {
      _switchValue = widget.positionedWidget.widget.pinConfig.first.value == 1;
    }
  }

  void _checkIf3DWidget() {
    try {
      final image = widget.positionedWidget.widget.image;
      if (image.startsWith('{')) {
        final config = json.decode(image);
        _is3DWidget =
            config is Map &&
            config.containsKey('type') &&
            config['type'].toString().contains('3d');
        debugPrint(
          'Checking if widget is 3D: $_is3DWidget (${config['name'] ?? 'unknown'})',
        );
      }
    } catch (e) {
      debugPrint('Error checking if widget is 3D: $e');
      _is3DWidget = false;
    }
  }

  void _updatePinValue(int value) {
    if (!widget.isPreviewMode) return;

    if (widget.positionedWidget.widget.pinConfig.isNotEmpty) {
      final updatedPinConfig =
          widget.positionedWidget.widget.pinConfig.map((pin) {
            return pin.copyWith(value: value);
          }).toList();

      // Update the widget's pin configuration
      final updatedWidget = widget.positionedWidget.widget.copyWith(
        pinConfig: updatedPinConfig,
      );

      // Update the positioned widget with the new widget
      final updatedPositionedWidget = widget.positionedWidget.copyWith(
        widget: updatedWidget,
      );

      // Notify parent about the change
      widget.onPositionChanged(updatedPositionedWidget.position);
    }
  }

  void _handleValueChanged(bool newValue) {
    setState(() {
      _switchValue = newValue;
    });
    widget.onValueChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isPreviewMode ? null : widget.onTap,
      onPanStart:
          widget.isPreviewMode
              ? null
              : (details) {
                setState(() {
                  _isDragging = true;
                  // Store the initial touch position and widget position
                  _dragStartPosition = details.globalPosition;
                  _widgetStartPosition = Offset(
                    widget.positionedWidget.position.x,
                    widget.positionedWidget.position.y,
                  );
                });
                debugPrint(
                  'Drag start: ${widget.positionedWidget.id} at position (${widget.positionedWidget.position.x}, ${widget.positionedWidget.position.y})',
                );
              },
      onPanUpdate:
          widget.isPreviewMode
              ? null
              : (details) {
                // Calculate the delta from the start position
                final dx = details.globalPosition.dx - _dragStartPosition.dx;
                final dy = details.globalPosition.dy - _dragStartPosition.dy;

                // Apply the delta to the original widget position
                final newPosition = app_widget.Position(
                  x: _widgetStartPosition.dx + dx,
                  y: _widgetStartPosition.dy + dy,
                );

                // Ensure position is never negative
                final safeX =
                    newPosition.x < 0 ? 0.0 : newPosition.x.toDouble();
                final safeY =
                    newPosition.y < 0 ? 0.0 : newPosition.y.toDouble();

                final updatedPosition = app_widget.Position(x: safeX, y: safeY);
                widget.onPositionChanged(updatedPosition);

                debugPrint(
                  'Dragging widget ${widget.positionedWidget.id} to (${updatedPosition.x}, ${updatedPosition.y})',
                );
              },
      onPanEnd:
          widget.isPreviewMode
              ? null
              : (details) {
                setState(() {
                  _isDragging = false;
                });
                debugPrint(
                  'Drag end: ${widget.positionedWidget.id} at position (${widget.positionedWidget.position.x}, ${widget.positionedWidget.position.y})',
                );
              },
      // Use HitTestBehavior.opaque to ensure this widget gets all touch events
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border:
              _isDragging
                  ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                  : null,
        ),
        child: Stack(
          children: [
            // Widget content
            _buildInteractiveWidget(),

            // Remove button (only visible when not in preview mode)
            if (!widget.isPreviewMode)
              Positioned(
                top: -10,
                right: -10,
                child: GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveWidget() {
    if (_is3DWidget) {
      return Interactive3DWidget(
        widget: widget.positionedWidget.widget,
        isPreviewMode: widget.isPreviewMode,
        value: _switchValue,
        onValueChanged: _handleValueChanged,
      );
    }
    return _buildStandardWidget();
  }

  Widget _buildStandardWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              widget.positionedWidget.widget.image.startsWith('http')
                  ? Image.network(
                    widget.positionedWidget.widget.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.widgets_outlined,
                        size: 40,
                        color: Theme.of(context).primaryColor,
                      );
                    },
                  )
                  : Icon(
                    Icons.widgets_outlined,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.positionedWidget.widget.name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
