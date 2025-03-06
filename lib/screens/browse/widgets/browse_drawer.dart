import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:flutter/material.dart';

/// Drawer for the browse screen
class BrowseDrawer extends StatelessWidget {
  final String firstName;
  final String baseUrl;
  final VoidCallback onLogoutTap;

  const BrowseDrawer({
    Key? key,
    required this.firstName,
    required this.baseUrl,
    required this.onLogoutTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: EVColors.appBarBackground,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EisenVault',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome, $firstName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Server: $baseUrl',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Departments'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              onLogoutTap(); // Show logout confirmation
            },
          ),
        ],
      ),
    );
  }
}
