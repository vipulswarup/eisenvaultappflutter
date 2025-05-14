import 'package:eisenvaultappflutter/screens/login_screen.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Handles authentication and logout operations
class AuthHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;

  AuthHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
  });

  /// Shows logout confirmation dialog
  void showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout Confirmation"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Close the dialog
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                performLogout();
              },
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );
  }

  /// Performs the actual logout
  Future<void> performLogout() async {
    try {
      // Get auth state manager
      final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
      
      // Perform logout
      await authStateManager.logout();

    // Navigate back to login screen and remove all previous routes
      if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
