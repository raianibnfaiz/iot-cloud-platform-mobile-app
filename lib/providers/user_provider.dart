import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  String _userEmail = '';
  String _displayName = '';
  String _userId = '';
  String? _profilePicture;
  final APIService _apiService = APIService();

  String get userEmail => _userEmail;
  String get displayName => _displayName;
  String get userId => _userId;
  String? get profilePicture => _profilePicture;

  Future<void> loadUserData() async {
    try {
      // Get data from server
      final serverData = await _apiService.getUserData();
      
      // Get locally stored auth data
      final authService = AuthService();
      final authData = await authService.getUserData();

      debugPrint("Profile Picture: ${authData['profilePicture']}");

      // Use server data for ID, but fall back to stored data if needed
      _userId = serverData?['user_id']?.toString() ?? '';
      _userEmail = serverData?['user_email'] ?? authData['email'] ?? '';
      _displayName = serverData?['name'] ?? authData['name'] ?? '';
      _profilePicture = authData['profilePicture']; // Keep Google profile picture

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
      // Fall back to stored auth data if server request fails
      final authService = AuthService();
      final authData = await authService.getUserData();
      
      _userEmail = authData['email'] ?? '';
      _displayName = authData['name'] ?? '';
      _userId = authData['userId'] ?? '';
      _profilePicture = authData['profilePicture'];

      notifyListeners();
    }
  }
}
