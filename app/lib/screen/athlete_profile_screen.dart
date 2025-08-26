import 'package:flutter/material.dart';

class AthleteProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const AthleteProfileScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Your Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header with larger profile image
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 50,
                  child: Text(
                    userData['name']?.substring(0, 1).toUpperCase() ?? 'A',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '${userData['name'] ?? 'Athlete'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  userData['email'] ?? 'No email',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Profile content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 16),
                    child: Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // Profile Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            icon: Icons.person,
                            label: 'Name',
                            value: userData['name'] ?? 'N/A',
                          ),
                          Divider(),
                          _buildInfoRow(
                            icon: Icons.email,
                            label: 'Email',
                            value: userData['email'] ?? 'N/A',
                          ),
                          Divider(),
                          _buildInfoRow(
                            icon: Icons.badge,
                            label: 'User ID',
                            value: userData['id'] ?? 'N/A',
                          ),
                          Divider(),
                          _buildInfoRow(
                            icon: Icons.sports,
                            label: 'Role',
                            value: userData['role'] ?? 'athlete',
                          ),
                          Divider(),
                          _buildInfoRow(
                            icon: Icons.person_outline,
                            label: 'Gender',
                            value: userData['gender'] ?? 'N/A',
                          ),
                          Divider(),
                          _buildInfoRow(
                            icon: Icons.calendar_today,
                            label: 'Age',
                            value: userData['age']?.toString() ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Additional options section
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 16),
                    child: Text(
                      'Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // Options Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildOptionTile(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          subtitle: 'Configure notification settings',
                          onTap: () {
                            // Handle notifications setting
                          },
                        ),
                        Divider(height: 1),
                        _buildOptionTile(
                          icon: Icons.privacy_tip,
                          title: 'Privacy',
                          subtitle: 'Manage your data and privacy',
                          onTap: () {
                            // Handle privacy settings
                          },
                        ),
                        Divider(height: 1),
                        _buildOptionTile(
                          icon: Icons.help,
                          title: 'Help & Support',
                          subtitle: 'Get assistance and answers',
                          onTap: () {
                            // Handle help
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/welcome');
                      },
                      icon: Icon(Icons.logout),
                      label: Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.purple.shade700, size: 20),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.purple.shade700, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
