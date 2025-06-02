import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthWrapper extends StatefulWidget {
  final Widget child;

  const BiometricAuthWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<BiometricAuthWrapper> createState() => _BiometricAuthWrapperState();
}

class _BiometricAuthWrapperState extends State<BiometricAuthWrapper>
    with WidgetsBindingObserver {
  final BiometricAuthService _authService = BiometricAuthService();
  bool _isAuthenticated = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_isAuthenticated &&
        _isBiometricEnabled) {
      _authenticate();
    }
  }

  Future<void> _checkBiometricStatus() async {
    final isBiometricAvailable = await _authService.isBiometricAvailable();
    final isBiometricEnabled = await _authService.isBiometricEnabled();

    setState(() {
      _isBiometricAvailable = isBiometricAvailable;
      _isBiometricEnabled = isBiometricEnabled;
    });

    if (_isBiometricAvailable && _isBiometricEnabled) {
      _authenticate();
    } else {
      setState(() {
        _isAuthenticated = true;
      });
    }
  }

  Future<void> _authenticate() async {
    final authenticated = await _authService.authenticate();
    setState(() {
      _isAuthenticated = authenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBiometricEnabled || _isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 72, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Biometric Authentication Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please authenticate to access the app',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('Authenticate'),
            ),
          ],
        ),
      ),
    );
  }
}
