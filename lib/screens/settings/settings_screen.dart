import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/base_screen.dart';
import '../../services/auth_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:app_settings/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  final BiometricAuthService _authService = BiometricAuthService();
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    final isBiometricAvailable = await _authService.isBiometricAvailable();
    final isBiometricEnabled = await _authService.isBiometricEnabled();
    final availableBiometrics = await _authService.getAvailableBiometrics();

    setState(() {
      _isBiometricAvailable = isBiometricAvailable;
      _isBiometricEnabled = isBiometricEnabled;
      _availableBiometrics = availableBiometrics;
    });
  }

  String _getBiometricType() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.strong) ||
        _availableBiometrics.contains(BiometricType.weak)) {
      return 'Biometric';
    }
    return 'Not Available';
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face_outlined;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint_outlined;
    }
    return Icons.security_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Settings',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'General',
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Use System Theme'),
                          subtitle: const Text('Follow system dark/light mode'),
                          value: themeProvider.useSystemTheme,
                          onChanged: (value) {
                            themeProvider.setUseSystemTheme(value);
                          },
                          secondary: const Icon(
                            Icons.brightness_auto,
                            color: Color(0xFF2ECC71),
                          ),
                        ),
                        if (!themeProvider.useSystemTheme)
                          SwitchListTile(
                            title: const Text('Dark Mode'),
                            subtitle: const Text('Enable dark theme'),
                            value: themeProvider.isDarkMode,
                            onChanged: (value) {
                              themeProvider.setThemeMode(value);
                            },
                            secondary: const Icon(
                              Icons.dark_mode_outlined,
                              color: Color(0xFF2ECC71),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.language_outlined,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Language'),
                  subtitle: Text(_selectedLanguage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Handle language selection
                  },
                ),
              ],
            ),
            _buildSection(
              title: 'Notifications',
              children: [
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive push notifications'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                  secondary: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF2ECC71),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Email Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Handle email notification settings
                  },
                ),
              ],
            ),
            _buildSection(
              title: 'Security',
              children: [
                if (_isBiometricAvailable) ...[
                  SwitchListTile(
                    title: const Text('Enable Biometric Authentication'),
                    subtitle: Text(
                      'Use ${_getBiometricType()} to unlock the app',
                    ),
                    value: _isBiometricEnabled,
                    onChanged: (bool value) async {
                      try {
                        if (value) {
                          // Verify biometric before enabling
                          final authenticated =
                              await _authService.authenticate();
                          if (authenticated) {
                            await _authService.setBiometricEnabled(true);
                            setState(() {
                              _isBiometricEnabled = true;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Biometric authentication enabled',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } else {
                          // Verify biometric before disabling
                          final authenticated =
                              await _authService.authenticate();
                          if (authenticated) {
                            await _authService.setBiometricEnabled(false);
                            setState(() {
                              _isBiometricEnabled = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Biometric authentication disabled',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        }
                      } on PlatformException catch (e) {
                        debugPrint('Platform Exception: ${e.message}');
                        // Reset switch to previous state
                        setState(() {
                          _isBiometricEnabled = !value;
                        });

                        if (e.code == auth_error.notEnrolled) {
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text(
                                      'Biometric Setup Required',
                                    ),
                                    content: const Text(
                                      'You need to set up biometric authentication in your device settings first. Would you like to open settings now?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          await AppSettings.openAppSettings();
                                        },
                                        child: const Text('Open Settings'),
                                      ),
                                    ],
                                  ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.message ?? 'Authentication failed',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('Error toggling biometric: $e');
                        // Reset switch to previous state
                        setState(() {
                          _isBiometricEnabled = !value;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    secondary: Icon(
                      _getBiometricIcon(),
                      color: const Color(0xFF2ECC71),
                    ),
                  ),
                  const Divider(),
                ],
                ListTile(
                  leading: const Icon(
                    Icons.fingerprint_outlined,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Biometric Authentication'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Handle biometric settings
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.password_outlined,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Handle password change
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.security_outlined,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Two-Factor Authentication'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Handle 2FA settings
                  },
                ),
              ],
            ),
            _buildSection(
              title: 'Data & Storage',
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.storage_outlined,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Storage Usage'),
                  trailing: const Text('1.2 GB'),
                  onTap: () {
                    // Handle storage settings
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Clear Cache'),
                  subtitle: const Text('Free up storage space'),
                  onTap: () {
                    // Handle clear cache
                  },
                ),
              ],
            ),
            _buildSection(
              title: 'About',
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Version'),
                  trailing: const Text('1.0.0'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Handle terms of service
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFF2ECC71),
                  ),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Handle privacy policy
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
