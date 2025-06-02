import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import '../models/template.dart';
import '../services/template_service.dart';

class TemplateProvider extends ChangeNotifier {
  final TemplateService _templateService = TemplateService();
  Template? _currentTemplate;

  Template? get currentTemplate => _currentTemplate;

  void setCurrentTemplate(Template template) {
    _currentTemplate = template;
    notifyListeners();
  }

  Future<void> onWidgetMoved(String widgetId, Offset newPosition, List<String> pinConfig) async {
    if (_currentTemplate == null) {
      debugPrint('No template selected');
      return;
    }

    try {
      // Find the widget in the current template
      final existingWidget = _currentTemplate!.widgetList.firstWhere(
        (w) => w.widgetId == widgetId,
        orElse: () => throw Exception('Widget not found in template'),
      );
      
      // Create an updated widget with the new position
      final widget = TemplateWidget(
        widgetId: widgetId,
        name: existingWidget.name,
        image: existingWidget.image,
        pinRequired: existingWidget.pinRequired,
        pinConfig: existingWidget.pinConfig,
        id: existingWidget.id,
        position: Position(
          x: newPosition.dx,
          y: newPosition.dy,
        ),
        configuration: existingWidget.configuration,
      );

      final updatedTemplate = await _templateService.updateTemplate(
        _currentTemplate!,
        [widget],
      );

      _currentTemplate = updatedTemplate;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update widget position: $e');
      // Handle error, maybe revert the widget position
    }
  }
} 