import 'package:flutter/material.dart';
import '../../widgets/base_screen.dart';

class OrganizationScreen extends StatelessWidget {
  const OrganizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'My Organization',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrganizationCard(),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Members',
              children: [
                _buildMemberTile(
                  name: 'John Doe',
                  role: 'Admin',
                  email: 'john.doe@example.com',
                  isActive: true,
                ),
                _buildMemberTile(
                  name: 'Jane Smith',
                  role: 'Developer',
                  email: 'jane.smith@example.com',
                  isActive: true,
                ),
                _buildMemberTile(
                  name: 'Mike Johnson',
                  role: 'Viewer',
                  email: 'mike.j@example.com',
                  isActive: false,
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2ECC71),
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                  title: const Text('Invite Member'),
                  onTap: () {
                    // Handle invite member
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Projects',
              children: [
                _buildProjectTile(
                  name: 'Smart Home System',
                  devices: 12,
                  status: 'Active',
                ),
                _buildProjectTile(
                  name: 'Industrial Monitoring',
                  devices: 8,
                  status: 'Active',
                ),
                _buildProjectTile(
                  name: 'Weather Station',
                  devices: 3,
                  status: 'Inactive',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[100],
                  child: const Text(
                    'B',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BJIT Limited',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Organization ID: 8582MM',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildStatRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStat('Members', '15'),
        _buildStat('Projects', '3'),
        _buildStat('Devices', '23'),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2196F3),
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
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

  Widget _buildMemberTile({
    required String name,
    required String role,
    required String email,
    required bool isActive,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF2ECC71),
        child: Text(name[0], style: const TextStyle(color: Colors.white)),
      ),
      title: Text(name),
      subtitle: Text(email),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              isActive
                  ? const Color(0xFF2ECC71).withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          role,
          style: TextStyle(
            color: isActive ? const Color(0xFF2ECC71) : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProjectTile({
    required String name,
    required int devices,
    required String status,
  }) {
    return ListTile(
      title: Text(name),
      subtitle: Text('$devices devices'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              status == 'Active'
                  ? const Color(0xFF2ECC71).withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: status == 'Active' ? const Color(0xFF2ECC71) : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
