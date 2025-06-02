import 'package:bjit_iot_platform_mobile_app/providers/theme_provider.dart';
import 'package:bjit_iot_platform_mobile_app/providers/user_provider.dart';
import 'package:bjit_iot_platform_mobile_app/providers/widget_provider.dart';
import 'package:bjit_iot_platform_mobile_app/screens/auth/login_screen.dart';
import 'package:bjit_iot_platform_mobile_app/screens/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'services/auth_service.dart';
import 'services/widget_service.dart';
import 'widgets/biometric_auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Platform.isAndroid) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyAy0f18fFiKpv4NEnhWk6VgQ-9fAQ8tFeQ',
          appId: '1:938547830302:android:34748d1bafa1eef42fd80f',
          messagingSenderId: '938547830302',
          projectId: 'iot-cloud-platform-app',
          
          iosClientId:
              '600838284804-7i53pr6ssiejettt1aro3cdmumql5bn4.apps.googleusercontent.com',
          androidClientId:
              '938547830302-v6driok5kg1ochpo3j4idbqopgru2qp4.apps.googleusercontent.com',
        ),
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  await SharedPreferences.getInstance();

  // Initialize Hive and widget service
  final widgetService = WidgetService();
  await widgetService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => WidgetProvider()..loadWidgets()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => WidgetProvider()..loadWidgets()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'BJIT IoT Platform',
            debugShowCheckedModeBanner: false,
            themeMode:
                themeProvider.useSystemTheme
                    ? ThemeMode.system
                    : themeProvider.isDarkMode
                    ? ThemeMode.dark
                    : ThemeMode.light,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            home: BiometricAuthWrapper(child: const AuthWrapper()),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
      if (isLoggedIn) {
        // Load user data when logged in
        await context.read<UserProvider>().loadUserData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _isLoggedIn ? const DashboardScreen() : const LoginScreen();
  }
}
