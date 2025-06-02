import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/template.dart';

class APIService {
  static const String baseUrl =
       //'https://cloud-platform-server-for-bjit.onrender.com';
  'http://192.168.155.232:3000';
  static const String _tokenKey = 'server_token';
  static const String _userKey = 'user_data';

  static final APIService _instance = APIService._internal();

  factory APIService() {
    return _instance;
  }

  APIService._internal();

  Future<Map<String, dynamic>> loginWithSocialAuth({
    required String email,
    required String authToken,
  }) async {
    try {
      debugPrint('Attempting to login with email: $email');
      final response = await http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({'user_email': email, 'auth_token': authToken}),
      );

      debugPrint('Server response status: ${response.statusCode}');
      debugPrint('Server response body: ${response.body}');

      final data = jsonDecode(response.body);
      print('Token: ${authToken}');

      if (response.statusCode == 200 ||
          (data['token'] != null && data['user'] != null)) {
        debugPrint('Login successful, saving data...');
        await _saveServerToken(data['token']);
        await _saveUserData(data['user']);
        return data;
      } else {
        throw Exception('Failed to login: ${response.body}');
      }
    } catch (e) {
      if (e is FormatException) {
        debugPrint('Error parsing response: $e');
        throw Exception('Invalid server response format');
      } else {
        debugPrint('Server connection error: $e');
        throw Exception('Failed to connect to server: $e');
      }
    }
  }

  Future<void> _saveServerToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userData));
  }

  Future<String?> getServerToken() async {
    final prefs = await SharedPreferences.getInstance();
    print("token : ${prefs.getString(_tokenKey)}");
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userKey);
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  Future<void> clearServerData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<Map<String, dynamic>> createTemplate({
    required String templateName,
    required String userId,
  }) async {
    try {
      final token = await getServerToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/users/templates?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'template_name': templateName, 'widget_list': []}),
      );

      debugPrint('Create template response status: ${response.statusCode}');
      debugPrint('Create template response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      if (responseData['status'] == 'success') {
        return responseData;
      } else {
        throw Exception('Failed to create template: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error creating template: $e');
      throw Exception('Failed to create template: $e');
    }
  }

  Future<Map<String, dynamic>> updateTemplate(String templateId, List<TemplateWidget> widgetList) async {
    try {
      final token = await getServerToken();
      if (token == null) throw Exception('No auth token found');

      final requestBody = {
        'template_id': templateId,
        'widget_list': widgetList.map((widget) {
          return {
            'widget_id': widget.widgetId,
            'name': widget.name,
            'image': widget.image,
            'pinRequired': widget.pinRequired,
            'pinConfig': widget.pinConfig.map((pin) => {
              'virtualPin': pin.virtualPin,
              'value': pin.value,
              'id': pin.id,
            }).toList(),
            'position': widget.position?.toJson() ?? {'x': 0.0, 'y': 0.0},
            'configuration': widget.configuration ?? {},
          };
        }).toList(),
      };

      debugPrint('Update template request body: ${jsonEncode(requestBody)}');

      final response = await http.put(
        Uri.parse('$baseUrl/users/templates/$templateId'),
        headers: {
          'Content-Type': 'application/json',
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
        return responseData;
      } else {
        final errorMessage = responseData['message'] ?? 'Failed to update template';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Error updating template: $e');
      throw Exception('Failed to update template: $e');
    }
  }
}
