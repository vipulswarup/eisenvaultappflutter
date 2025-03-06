import 'package:eisenvaultappflutter/screens/login_screen.dart';
import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:flutter/material.dart';

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
  void performLogout() {
    // For Classic instance - clear token if needed
    if (instanceType == 'Classic') {
      // No persistent token storage in the current implementation
    } 
    // For Angora instance - clear token
    else if (instanceType == 'Angora') {
      final authService = AngoraAuthService(baseUrl);
      authService.setToken(null); // Clear the token
    }

    // Navigate back to login screen and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }
}
