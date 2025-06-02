import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/template.dart';
import '../models/virtual_pin.dart';
import 'api_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class TemplateService {
  static final TemplateService _instance = TemplateService._internal();
  final APIService _apiService = APIService();

  // Stream controller for template updates
  final _templateUpdateController = StreamController<Template>.broadcast();
  Stream<Template> get onTemplateUpdate => _templateUpdateController.stream;

  factory TemplateService() {
    return _instance;
  }

  TemplateService._internal();

  Future<List<Template>> getTemplates() async {
    try {
      debugPrint('Getting templates');
      final token = await _apiService.getServerToken();
      if (token == null) throw Exception('No auth token found');
      debugPrint("token: $token");

      final response = await http.get(
        Uri.parse('${APIService.baseUrl}/users/templates'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Get templates response status: ${response.statusCode}');
      debugPrint('Get templates response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) {
          debugPrint('No templates found');
          return [];
        }
        return data.map((json) => Template.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to load templates');
      }
    } catch (e) {
      debugPrint('Error getting templates: $e');
      throw Exception('Failed to load templates: $e');
    }
  }

  Future<Template> createTemplate(String templateName) async {
    try {
      debugPrint('Creating template');
      final token = await _apiService.getServerToken();
      if (token == null) throw Exception('No auth token found');

      final response = await http.post(
        Uri.parse('${APIService.baseUrl}/users/templates'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'template_name': templateName, 'widget_list': []}),
      );

      final responseData = jsonDecode(response.body);

      if (responseData['status'] == 'success' &&
          responseData['template'] != null) {
        return Template.fromJson(responseData['template']);
      } else {
        throw Exception('Failed to create template: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to create template: $e');
    }
  }

  Future<Template> updateTemplate(
    Template template,
    List<TemplateWidget> widgetList,
  ) async {
    try {
      debugPrint('Updating template');
      debugPrint('Template ID: ${template.templateId}');
      debugPrint('Widget list count: ${widgetList.length}');
      debugPrint(
        'First widget details: ${widgetList.isNotEmpty ? '${widgetList.first.widgetId} (${widgetList.first.name})' : 'No widgets'}',
      );

      final token = await _apiService.getServerToken();
      if (token == null) throw Exception('No auth token found');

      debugPrint('Got auth token: ${token.substring(0, 10)}...');

      // Filter out widgets with empty IDs to prevent MongoDB ObjectId casting errors
      final validWidgets =
          widgetList
              .where(
                (widget) =>
                    widget.widgetId.isNotEmpty && widget.widgetId != "null",
              )
              .toList();

      if (validWidgets.length != widgetList.length) {
        debugPrint(
          'WARNING: Filtered out ${widgetList.length - validWidgets.length} widgets with empty or null IDs',
        );
      }

      // Format the request body according to the API requirements - simplified format
      final requestBody = {
        'template_id': template.templateId,
        'widget_list':
            validWidgets.map((widget) {
              // Simplified format as shown in the curl example
              return {
                'widget_id': widget.widgetId,
                'pinConfig':
                    widget.pinConfig
                        .map((pin) => pin.id)
                        .toList(), // Just the pin IDs as an array
                'position': {
                  'x': widget.position?.x ?? 0.0,
                  'y': widget.position?.y ?? 0.0,
                },
              };
            }).toList(),
        // Keep the original virtual pins from the template with updated is_used flags
        'virtual_pins':
            template.virtual_pins.map((pin) => pin.toJson()).toList(),
      };

      debugPrint('Update template request body: ${jsonEncode(requestBody)}');

      final response = await http.put(
        Uri.parse(
          '${APIService.baseUrl}/users/templates/${template.templateId}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('Update template response status: ${response.statusCode}');
      debugPrint('Update template response body: ${response.body}');

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        // Create a new template using the response data if possible
        try {
          if (responseData['data'] != null &&
              responseData['data'] is Map<String, dynamic>) {
            return Template.fromJson(responseData['data']);
          }
        } catch (e) {
          debugPrint('Error parsing response template: $e');
        }

        // If that fails, fetch fresh template data
        final templates = await getTemplates();
        final updatedTemplate = templates.firstWhere(
          (t) => t.templateId == template.templateId,
          orElse: () => throw Exception('Updated template not found'),
        );
        // Notify listeners about the template update
        _templateUpdateController.add(updatedTemplate);
        return updatedTemplate;
      } else {
        final errorMessage =
            responseData['message'] ?? 'Failed to update template';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Error updating template: $e');
      rethrow;
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      debugPrint('Deleting template with ID: $templateId');
      final token = await _apiService.getServerToken();
      if (token == null) throw Exception('No auth token found');

      final response = await http.delete(
        Uri.parse('${APIService.baseUrl}/users/templates/${templateId}'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        'Delete template URL: ${APIService.baseUrl}/users/templates/${templateId}',
      );
      debugPrint('Delete template response status: ${response.statusCode}');
      debugPrint('Delete template response body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete template');
      }
    } catch (e) {
      debugPrint('Error deleting template: $e');
      throw Exception('Failed to delete template: $e');
    }
  }

  Future<Template> getTemplate(String templateId) async {
    try {
      debugPrint('Getting template by ID: $templateId');
      final token = await _apiService.getServerToken();
      if (token == null) throw Exception('No auth token found');

      // First get all templates and find the one we want
      final templates = await getTemplates();
      final template = templates.firstWhere(
        (t) => t.templateId == templateId,
        orElse: () => throw Exception('Template not found'),
      );
      return template;
    } catch (e) {
      debugPrint('Error getting template: $e');
      throw Exception('Failed to load template: $e');
    }
  }

  Future<bool> updateVirtualPin({
    required String templateId,
    required String pinId,
    required String pinName,
    required int value,
    required int minValue,
    required int maxValue,
    required bool isUsed,
  }) async {
    try {
      final url = Uri.parse(
        '${APIService.baseUrl}/users/templates/virtualPins/$pinId?template_id=$templateId',
      );

      final response = await http.put(
        url,
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer ${await _apiService.getServerToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pin_id': pinId,
          'pin_name': pinName,
          'value': value,
          'min_value': minValue,
          'max_value': maxValue,
          'is_used': isUsed,
        }),
      );

      debugPrint('Update virtual pin response status: ${response.statusCode}');
      debugPrint('Update virtual pin response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating virtual pin: $e');
      return false;
    }
  }

  Future<bool> saveTemplateWidgets(
    String templateId,
    List<TemplateWidget> widgetList,
  ) async {
    try {
      debugPrint('Saving template widgets');
      debugPrint('Template ID: $templateId');
      debugPrint('Widget list count: ${widgetList.length}');

      final token = await _apiService.getServerToken();
      if (token == null) throw Exception('No auth token found');

      // Filter out widgets with empty IDs
      final validWidgets =
          widgetList
              .where(
                (widget) =>
                    widget.widgetId.isNotEmpty && widget.widgetId != "null",
              )
              .toList();

      // Format request body according to the API requirements
      final requestBody = {
        'widget_list':
            validWidgets
                .map(
                  (widget) => {
                    'widget_id': widget.widgetId,
                    'pinConfig': widget.pinConfig.map((pin) => pin.id).toList(),
                    'position': {
                      'x': widget.position?.x ?? 0.0,
                      'y': widget.position?.y ?? 0.0,
                    },
                  },
                )
                .toList(),
      };

      debugPrint(
        'Save template widgets request body: ${jsonEncode(requestBody)}',
      );

      final response = await http.put(
        Uri.parse('${APIService.baseUrl}/users/templates/$templateId'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint(
        'Save template widgets response status: ${response.statusCode}',
      );
      debugPrint('Save template widgets response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error saving template widgets: $e');
      return false;
    }
  }

  Future<List<VirtualPin>> getVirtualPins(String templateId) async {
    try {
      debugPrint('Fetching virtual pins for template: $templateId');

      final token = await _apiService.getServerToken();
      if (token == null) throw Exception('No auth token found');

      final response = await http.get(
        Uri.parse(
          '${APIService.baseUrl}/users/templates/virtualPins?template_id=$templateId',
        ),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Get virtual pins response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final pins = data.map((pin) => VirtualPin.fromJson(pin)).toList();

        debugPrint('Fetched ${pins.length} virtual pins');
        return pins;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch virtual pins');
      }
    } catch (e) {
      debugPrint('Error fetching virtual pins: $e');
      throw Exception('Failed to fetch virtual pins: $e');
    }
  }

  void dispose() {
    _templateUpdateController.close();
  }
}
