import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/positioned_widget.dart';
import '../providers/playground_provider.dart';

class DraggableWidgetComponent extends StatefulWidget {
  final PositionedWidget positionedWidget;

  const DraggableWidgetComponent({super.key, required this.positionedWidget});

  @override
  State<DraggableWidgetComponent> createState() =>
      _DraggableWidgetComponentState();
}

class _DraggableWidgetComponentState extends State<DraggableWidgetComponent> {
  Offset? _startPosition;
  Offset? _startDragOffset;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaygroundProvider>(
      builder: (context, provider, child) {
        return Positioned(
          left: widget.positionedWidget.position.x,
          top: widget.positionedWidget.position.y,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              _startPosition = Offset(
                widget.positionedWidget.position.x,
                widget.positionedWidget.position.y,
              );
              _startDragOffset = details.globalPosition;
              provider.setDragging(true, widgetId: widget.positionedWidget.id);
            },
            onPanUpdate: (details) {
              if (_startPosition == null || _startDragOffset == null) return;

              final delta = details.globalPosition - _startDragOffset!;
              final newPosition = _startPosition! + delta;

              provider.updateWidgetPosition(
                widget.positionedWidget.id,
                newPosition,
              );
            },
            onPanEnd: (details) {
              _startPosition = null;
              _startDragOffset = null;
              provider.setDragging(false);
            },
            onPanCancel: () {
              _startPosition = null;
              _startDragOffset = null;
              provider.setDragging(false);
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border:
                    provider.isDragging &&
                            widget.positionedWidget.id ==
                                provider.draggedWidgetId
                        ? Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        )
                        : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.widgets_outlined,
                          color: Theme.of(context).primaryColor,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.positionedWidget.widget.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Material(
                      type: MaterialType.transparency,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed:
                            () => provider.removeWidget(
                              widget.positionedWidget.id,
                            ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
