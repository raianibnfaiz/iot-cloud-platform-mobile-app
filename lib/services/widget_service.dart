import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/widget.dart';
import 'api_service.dart';

class WidgetService {
  static const String _widgetBoxName = 'widgets';
  static final WidgetService _instance = WidgetService._internal();
  final APIService _apiService = APIService();
  bool _hasLoadedInitialData = false;
  bool _isInitializing = false;

  factory WidgetService() {
    return _instance;
  }

  WidgetService._internal();

  Future<void> initHive() async {
    try {
      await Hive.initFlutter();
      
      // Check if adapters are already registered to avoid the "already registered" error
      try {
        if (!Hive.isAdapterRegistered(2)) {
          Hive.registerAdapter(WidgetAdapter());
        }
        
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(PinConfigAdapter());
        }
        
        if (!Hive.isAdapterRegistered(3)) {
          Hive.registerAdapter(PositionAdapter());
        }
      } catch (e) {
        debugPrint('Error registering Hive adapters: $e');
        // Continue anyway, as the adapters might already be registered
      }
      
      await Hive.openBox<Widget>(_widgetBoxName);
    } catch (e) {
      debugPrint('Error initializing Hive: $e');
      // If we can't initialize Hive, we'll fall back to network-only mode
    }
  }

  /// Initialize the widget service and load initial data
  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      await initHive();
      // Try to load widgets from server
      await getWidgets(forceRefresh: true);
    } catch (e) {
      debugPrint('Error initializing widget service: $e');
      // Even if initialization fails, we'll still have cached data if available
    } finally {
      _isInitializing = false;
    }
  }

  Future<List<Widget>> getWidgets({bool forceRefresh = false}) async {
    final box = Hive.box<Widget>(_widgetBoxName);

    // If we have cached data and don't need to refresh, return it
    if (!forceRefresh && box.isNotEmpty && _hasLoadedInitialData) {
      debugPrint('Returning ${box.length} widgets from cache');
      return box.values.toList();
    }

    try {
      final token = await _apiService.getServerToken();
      if (token == null) throw Exception('No auth token found');

      debugPrint('Fetching widgets from server');
      final response = await http.get(
        Uri.parse('${APIService.baseUrl}/widgets'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Get widgets response status: ${response.statusCode}');
      debugPrint('Get widgets response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) {
          debugPrint('No widgets found from server');
          return [];
        }

        final widgets = data.map((json) {
          // Add default pinConfig if not present
          if (!json.containsKey('pinConfig')) {
            json['pinConfig'] = [];
          }
          return Widget.fromJson(json);
        }).toList();

        // Clear existing widgets and save new ones
        await box.clear();
        await box.addAll(widgets);

        _hasLoadedInitialData = true;
        debugPrint('Cached ${widgets.length} widgets');
        return widgets;
      } else {
        throw Exception('Failed to load widgets: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error loading widgets: $e');
      // Return cached data if available
      if (box.isNotEmpty) {
        debugPrint('Returning ${box.length} widgets from cache after error');
        return box.values.toList();
      }
      throw Exception('Failed to load widgets and no cached data available: $e');
    }
  }

  Future<void> clearCache() async {
    final box = Hive.box<Widget>(_widgetBoxName);
    await box.clear();
    _hasLoadedInitialData = false;
  }
}
