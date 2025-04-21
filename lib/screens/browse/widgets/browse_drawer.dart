import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_settings_screen.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:flutter/material.dart';

/// Drawer for the browse screen
class BrowseDrawer extends StatelessWidget {
  final String firstName;
  final String baseUrl;
  final String authToken;
  final String instanceType;
  final VoidCallback onLogoutTap;
  final OfflineManager offlineManager;

  const BrowseDrawer({
    Key? key,
    required this.firstName,
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    required this.onLogoutTap,
    required this.offlineManager,
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BrowseScreen(
                    baseUrl: baseUrl,
                    authToken: authToken,
                    firstName: firstName,
                    instanceType: instanceType,
                    customerHostname: '', // Add appropriate hostname if needed
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.offline_pin),
            title: const Text('Offline Settings'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OfflineSettingsScreen(
                    instanceType: instanceType,
                    baseUrl: baseUrl,
                    authToken: authToken,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Offline Content'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OfflineBrowseScreen(
                    baseUrl: baseUrl,
                    authToken: authToken,
                    firstName: firstName,
                    instanceType: instanceType,
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              offlineManager.clearOfflineContent(); // Clear offline content
              onLogoutTap(); // Handle logout
            },
          ),
        ],
      ),
    );
  }
}
