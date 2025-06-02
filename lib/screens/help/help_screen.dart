import 'package:flutter/material.dart';
import '../../widgets/base_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Help',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpHeader(),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Quick Actions',
              children: [
                _buildActionTile(
                  icon: Icons.chat_outlined,
                  title: 'Live Chat',
                  subtitle: 'Chat with our support team',
                  onTap: () {
                    // Handle live chat
                  },
                ),
                _buildActionTile(
                  icon: Icons.email_outlined,
                  title: 'Email Support',
                  subtitle: 'Send us an email',
                  onTap: () {
                    // Handle email support
                  },
                ),
                _buildActionTile(
                  icon: Icons.phone_outlined,
                  title: 'Call Support',
                  subtitle: '+1 234 567 890',
                  onTap: () {
                    // Handle phone call
                  },
                ),
              ],
            ),
            _buildSection(
              title: 'Frequently Asked Questions',
              children: [
                _buildExpandableFAQ(
                  question: 'How do I connect a new device?',
                  answer:
                      'To connect a new device, go to the dashboard and click on "Add Device". Follow the step-by-step instructions to complete the setup process.',
                ),
                _buildExpandableFAQ(
                  question: 'How do I reset my password?',
                  answer:
                      'Click on the "Forgot Password" link on the login screen. Enter your email address and follow the instructions sent to your email to reset your password.',
                ),
                _buildExpandableFAQ(
                  question: 'How do I invite team members?',
                  answer:
                      'Go to Organization > Members and click on "Invite Member". Enter their email address and select their role to send an invitation.',
                ),
                _buildExpandableFAQ(
                  question: 'What are Blueprints?',
                  answer:
                      'Blueprints are pre-configured templates that help you quickly set up common IoT projects. They include code examples and step-by-step guides.',
                ),
              ],
            ),
            _buildSection(
              title: 'Documentation',
              children: [
                _buildActionTile(
                  icon: Icons.library_books_outlined,
                  title: 'API Documentation',
                  subtitle: 'View API reference and guides',
                  onTap: () {
                    // Handle API docs
                  },
                ),
                _buildActionTile(
                  icon: Icons.code_outlined,
                  title: 'Code Examples',
                  subtitle: 'Browse sample projects',
                  onTap: () {
                    // Handle code examples
                  },
                ),
                _buildActionTile(
                  icon: Icons.school_outlined,
                  title: 'Tutorials',
                  subtitle: 'Learn step by step',
                  onTap: () {
                    // Handle tutorials
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How can we help you?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Find answers to common questions or contact our support team.',
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2ECC71)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildExpandableFAQ({
    required String question,
    required String answer,
  }) {
    return ExpansionTile(
      title: Text(question),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(answer, style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
