import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/material.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _authTypeKey = 'auth_type';
  static const String _profilePictureKey = 'profile_picture';
  static const String _userIdKey = 'user_id';

  static final AuthService _instance = AuthService._internal();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final APIService _apiService = APIService();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal() {
    // Listen to auth state changes
    _firebaseAuth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User is signed in
        final idToken = await user.getIdToken();
        final email = user.email;
        if (idToken != null && email != null) {
          final displayName = user.displayName ?? email.split('@')[0] ?? 'User';
          await _saveUserData(
            email: email,
            name: displayName,
            authType: _getAuthType(user),
            token: idToken,
          );
        }
      } else {
        // User is signed out
        await _clearUserData();
      }
    });
  }

  String _getAuthType(User user) {
    if (user.providerData.any((info) => info.providerId == 'google.com')) {
      return 'google';
    } else if (user.providerData.any(
      (info) => info.providerId == 'apple.com',
    )) {
      return 'apple';
    }
    return 'email';
  }

  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear all shared preferences data
    await prefs.clear();
    // Also clear server data
    await _apiService.clearServerData();
  }

  Future<bool> login(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final idToken = await userCredential.user!.getIdToken();
        if (idToken != null) {
          try {
            final serverResponse = await _apiService.loginWithSocialAuth(
              email: email,
              authToken: idToken,
            );

            // Server login successful, data will be saved by APIService
            return true;
          } catch (serverError) {
            print('Server connection error: $serverError');
            await _firebaseAuth.signOut();
            return false;
          }
        }
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(name);
        final idToken = await userCredential.user!.getIdToken();
        if (idToken != null) {
          await _saveUserData(
            email: email,
            name: name,
            authType: 'email',
            token: idToken,
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return {'success': false, 'error': 'Google Sign-In was cancelled'};
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final idToken = await userCredential.user?.getIdToken();
      final email = userCredential.user?.email;
      final displayName = userCredential.user?.displayName;
      final photoURL = userCredential.user?.photoURL;

      debugPrint("Id Token: $idToken");

      if (userCredential.user != null && idToken != null && email != null) {
        try {
          final serverResponse = await _apiService.loginWithSocialAuth(
            email: email,
            authToken: idToken,
          );

          // Save the complete user data, using server's user_id
          await _saveUserData(
            email: email,
            name: displayName ?? email.split('@')[0],
            authType: 'google',
            token: idToken,
            profilePicture: photoURL,
            userId: serverResponse['user']['user_id']?.toString(), // Use server's user_id field
          );

          return {
            'success': true,
            'user': serverResponse['user'],
            'token': serverResponse['token'],
          };
        } catch (serverError) {
          print('Server connection error: $serverError');
          await _firebaseAuth.signOut();
          await _googleSignIn.signOut();
          await _clearUserData();
          return {
            'success': false,
            'error': 'Failed to connect to server. Please try again later.',
            'details': serverError.toString(),
          };
        }
      }
      return {'success': false, 'error': 'Failed to get user credentials'};
    } catch (e) {
      print('Google Sign-In error: $e');
      try {
        await _firebaseAuth.signOut();
        await _googleSignIn.signOut();
        await _clearUserData();
      } catch (_) {}
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> signInWithApple() async {
    // Simulate loading delay
    await Future.delayed(const Duration(seconds: 2));

    // TODO: Implement actual Apple Sign-In later
    // For now, just simulate a successful sign-in
    await _saveUserData(
      email: 'apple.user@icloud.com',
      name: 'Apple User',
      authType: 'apple',
      token: 'dummy_apple_token',
    );
    return true;
  }

  Future<void> _saveUserData({
    required String email,
    String? name,
    required String authType,
    required String token,
    String? profilePicture,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
    if (name != null) {
      await prefs.setString(_userNameKey, name);
    }
    if (profilePicture != null) {
      await prefs.setString(_profilePictureKey, profilePicture);
    }
    if (userId != null) {
      await prefs.setString(_userIdKey, userId);
    }
    await prefs.setString(_authTypeKey, authType);
    await prefs.setString(_tokenKey, token);
  }

  Future<bool> forgotPassword(String email) async {
    // Mock forgot password - will be replaced with actual API call later
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    return true;
  }

  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();

    final prefs = await SharedPreferences.getInstance();
    final authType = prefs.getString(_authTypeKey);

    // If user was signed in with Google, sign out from Google as well
    if (authType == 'google') {
      await _googleSignIn.signOut();
    }

    // Clear all stored data
    await _clearUserData();

    // Clear server data
    await _apiService.clearServerData();

    // Clear biometric data
    final biometricService = BiometricAuthService();
    await biometricService.setBiometricEnabled(false);

    // Clear server data
    await _apiService.clearServerData();
  }

  Future<bool> isLoggedIn() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      final token = await currentUser.getIdToken();
      if (token != null) {
        await saveAuthToken(token);
        return true;
      }
    }
    return false;
  }

  Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_userEmailKey),
      'name': prefs.getString(_userNameKey),
      'authType': prefs.getString(_authTypeKey),
      'profilePicture': prefs.getString(_profilePictureKey),
      'userId': prefs.getString(_userIdKey),
    };
  }
}

class BiometricAuthService {
  static final BiometricAuthService _instance =
      BiometricAuthService._internal();
  final LocalAuthentication _auth = LocalAuthentication();
  final String _biometricEnabledKey = 'biometric_enabled';

  factory BiometricAuthService() {
    return _instance;
  }

  BiometricAuthService._internal();

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  Future<bool> authenticate() async {
    try {
      // First check if biometrics are enrolled
      final availableBiometrics = await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        debugPrint('No biometrics enrolled');
        throw PlatformException(
          code: auth_error.notEnrolled,
          message:
              'No biometrics enrolled. Please set up biometric authentication in your device settings.',
        );
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable) {
        debugPrint('No biometric hardware available');
      } else if (e.code == auth_error.notEnrolled) {
        debugPrint('No biometrics enrolled');
      } else if (e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut) {
        debugPrint('Biometric authentication locked out');
      }
      rethrow; // Rethrow to handle in the UI
    } catch (e) {
      debugPrint('Error during authentication: $e');
      rethrow;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }
}
