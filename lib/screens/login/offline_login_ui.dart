import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:flutter/material.dart';

class OfflineLoginUI extends StatelessWidget {
  final VoidCallback onTryOnlineLogin;

  const OfflineLoginUI({
    Key? key,
    required this.onTryOnlineLogin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/eisenvault_logo.png',
            height: 120,
          ),
          const SizedBox(height: 30),
          const Text(
            'You are currently offline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _browseOfflineContent(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: EVColors.buttonBackground,
              foregroundColor: EVColors.buttonForeground,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Browse Offline Content'),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: onTryOnlineLogin,
            child: const Text('Try Online Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _browseOfflineContent(BuildContext context) async {
    try {
      // Get offline manager
      final offlineManager = OfflineManager.createDefault();
      
      // Check if we have offline content
      final items = await offlineManager.getOfflineItems(null);
      if (items.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No offline content available.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Get saved credentials for offline browsing
      final credentials = await offlineManager.getSavedCredentials();
      
      if (credentials == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot access offline content without previously logging in.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Navigate to offline browse screen
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OfflineBrowseScreen(
              instanceType: credentials['instanceType']!,
              baseUrl: credentials['baseUrl']!,
              authToken: credentials['authToken']!,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing offline content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
