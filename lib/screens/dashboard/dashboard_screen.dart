import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/page_transition.dart';
import '../../widgets/theme_toggle.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../billing/billing_screen.dart';
import '../organization/organization_screen.dart';
import '../settings/settings_screen.dart';
import '../help/help_screen.dart';
import '../about/about_screen.dart';
import '../templates/templates_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BJIT IoT Platform'),
        elevation: 0,
        actions: [
          const ThemeToggle(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Handle notifications
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'B',
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'BJIT IoT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.person_outline,
                color: Color(0xFF2ECC71),
              ),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  SlidePageRoute(page: const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.credit_card_outlined,
                color: Color(0xFF2ECC71),
              ),
              title: const Text('Billing'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  SlidePageRoute(page: const BillingScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.business_outlined,
                color: Color(0xFF2ECC71),
              ),
              title: const Text('My Organization - 8582MM'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  SlidePageRoute(page: const OrganizationScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: Color(0xFF2ECC71),
              ),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  SlidePageRoute(page: const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Color(0xFF2ECC71)),
              title: const Text('Help'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  SlidePageRoute(page: const HelpScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF2ECC71)),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  SlidePageRoute(page: const AboutScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.logout_outlined,
                color: Color(0xFF2ECC71),
              ),
              title: const Text('Log Out'),
              onTap: () async {
                await _authService.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // _buildCard(
            //   title: 'Explore Blueprints',
            //   description:
            //       'Ready-to-use projects that include code example and step-by-step guide to create functional devices in minutes.',
            //   icon: Icons.description_outlined,
            //   color: const Color(0xFF3498DB),
            //   onTap: () {
            //     // Handle explore blueprints
            //   },
            // ),
            // const SizedBox(height: 16),
            // _buildCard(
            //   title: 'Add Device',
            //   description:
            //       'Have a pre-flashed device that is ready to be connected to Blynk IoT?',
            //   icon: Icons.add,
            //   color: const Color(0xFF2ECC71),
            //   onTap: () {
            //     // Handle add device
            //   },
            // ),
            // const SizedBox(height: 16),
            _buildCard(
              title: 'Developer Zone',
              description: 'Edit and configure your templates here',
              icon: Icons.build_outlined,
              color: const Color(0xFF2ECC71),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TemplatesScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
