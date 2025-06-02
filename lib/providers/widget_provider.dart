import 'package:flutter/material.dart';
import '../models/widget.dart' as app_widget;
import '../services/widget_service.dart';

class WidgetProvider extends ChangeNotifier {
  final WidgetService _widgetService = WidgetService();
  List<app_widget.Widget> _widgets = [];
  bool _isLoading = true;
  String? _error;
  bool _isInitialized = false;

  List<app_widget.Widget> get widgets => _widgets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadWidgets({bool forceRefresh = false}) async {
    if (_isInitialized && !forceRefresh) {
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Initialize the widget service if not already initialized
      if (!_isInitialized) {
        await _widgetService.initialize();
      }

      _widgets = await _widgetService.getWidgets(forceRefresh: forceRefresh);
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading widgets: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      // Don't rethrow the error - let the UI handle it
    }
  }

  Future<void> refreshWidgets() async {
    await loadWidgets(forceRefresh: true);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> clearCache() async {
    await _widgetService.clearCache();
    _isInitialized = false;
    await refreshWidgets();
  }

  // Get a widget by ID from the loaded widgets
  app_widget.Widget? getWidgetById(String id) {
    try {
      return _widgets.firstWhere((w) => w.id == id);
    } catch (e) {
      debugPrint('Widget with ID $id not found');
      return null;
    }
  }
}
