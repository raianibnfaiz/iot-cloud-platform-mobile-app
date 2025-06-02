import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/base_screen.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'My Profile',
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF2ECC71),
                  backgroundImage: userProvider.profilePicture != null
                      ? NetworkImage(userProvider.profilePicture!)
                      : null,
                  child: userProvider.profilePicture == null
                      ? const Icon(
                          Icons.person_outline,
                          size: 50,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  userProvider.displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userProvider.userEmail,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                _buildSection(
                  title: 'Account Information',
                  children: [
                    _buildInfoTile(
                      icon: Icons.fingerprint,
                      title: 'User ID',
                      subtitle: userProvider.userId,
                    ),
                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      subtitle: userProvider.userEmail,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Account Settings',
                  children: [
                    _buildActionTile(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: () {
                        // Handle change password
                      },
                    ),
                    _buildActionTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notification Settings',
                      onTap: () {
                        // Handle notification settings
                      },
                    ),
                    _buildActionTile(
                      icon: Icons.security_outlined,
                      title: 'Privacy Settings',
                      onTap: () {
                        // Handle privacy settings
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 0),
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
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2ECC71)),
      title: Text(title),
      subtitle: Text(subtitle),
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
