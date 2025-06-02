import 'package:flutter/material.dart';
import '../../widgets/base_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'About',
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSection(
              title: 'App Information',
              children: [
                _buildInfoTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  subtitle: '1.0.0 (Build 100)',
                ),
                _buildInfoTile(
                  icon: Icons.update_outlined,
                  title: 'Last Updated',
                  subtitle: 'February 11, 2024',
                ),
                _buildInfoTile(
                  icon: Icons.devices_outlined,
                  title: 'Platform',
                  subtitle: 'Android & iOS',
                ),
              ],
            ),
            _buildSection(
              title: 'Company',
              children: [
                _buildInfoTile(
                  icon: Icons.business_outlined,
                  title: 'BJIT Limited',
                  subtitle: 'Leading IoT Solutions Provider',
                ),
                _buildInfoTile(
                  icon: Icons.location_on_outlined,
                  title: 'Headquarters',
                  subtitle: 'Dhaka, Bangladesh',
                ),
                _buildInfoTile(
                  icon: Icons.language_outlined,
                  title: 'Website',
                  subtitle: 'www.bjitgroup.com',
                  onTap: () {
                    // Handle website link
                  },
                ),
              ],
            ),
            _buildSection(
              title: 'Legal',
              children: [
                _buildActionTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () {
                    // Handle terms of service
                  },
                ),
                _buildActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () {
                    // Handle privacy policy
                  },
                ),
                _buildActionTile(
                  icon: Icons.gavel_outlined,
                  title: 'Licenses',
                  onTap: () {
                    // Handle licenses
                  },
                ),
              ],
            ),
            _buildSection(
              title: 'Connect With Us',
              children: [
                _buildActionTile(
                  icon: Icons.mail_outline,
                  title: 'Contact Us',
                  onTap: () {
                    // Handle contact
                  },
                ),
                _buildActionTile(
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                  onTap: () {
                    // Handle feedback
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '© 2024 BJIT Limited. All rights reserved.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                'B',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'BJIT IoT Platform',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Empowering IoT Innovation',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
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
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2ECC71)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2ECC71)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
