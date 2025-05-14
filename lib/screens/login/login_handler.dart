import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';
import 'package:eisenvaultappflutter/services/api/base_service.dart';
import 'package:eisenvaultappflutter/services/auth/classic_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';
import 'package:eisenvaultappflutter/widgets/error_display.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

/// Handles login logic and authentication, including offline mode
class LoginHandler {
  /// Performs login with the provided credentials
  Future<void> performLogin({
    required BuildContext context,
    required String baseUrl,
    required String username,
    required String password,
    required String instanceType,
  }) async {
    try {
      // Force Classic instance type
      const instanceType = 'Classic';
      
      // For Classic instances, append /alfresco if not present
      if (!baseUrl.endsWith('/alfresco')) {
        baseUrl = '$baseUrl/alfresco';
      }

      // Perform login using Classic auth service
      final authService = ClassicAuthService(baseUrl);
      final loginResult = await authService.makeRequest(
        'login',
        requestFunction: () => authService.login(username, password)
      );

      if (!context.mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login Successful!'),
          backgroundColor: EVColors.alertSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Set customer hostname for Classic
      const customerHostname = 'classic-repository';
      
      // Update auth state
      final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
      await authStateManager.handleSuccessfulLogin(
        token: loginResult['token'],
        username: username,
        firstName: loginResult['firstName'] ?? 'User',
        instanceType: instanceType,
        baseUrl: baseUrl,
        customerHostname: customerHostname,
      );
      
      // Initialize offline components
      await _initializeOfflineComponents(
        instanceType: instanceType,
        baseUrl: baseUrl,
        authToken: loginResult['token'],
        username: username,
      );

      // Navigate to browse screen
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BrowseScreen(
              baseUrl: baseUrl,
              authToken: loginResult['token'],
              firstName: loginResult['firstName'] ?? 'User',
              instanceType: instanceType,
              customerHostname: customerHostname,
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      
      String errorMessage = 'Login failed';
      
      // Handle specific error cases
      if (e is SocketException) {
        errorMessage = 'Network error: Unable to connect to the server. Please check your internet connection and try again.';
      } else if (e is HttpException) {
        errorMessage = 'Server error: The server is not responding correctly. Please try again later.';
      } else if (e is ServiceException) {
        errorMessage = e.toString();
      } else {
        errorMessage = 'An unexpected error occurred: ${e.toString()}';
      }
      
      // Show error dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: EVColors.screenBackground,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minWidth: 300,
              maxHeight: 250,
            ),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0
                  ),
                  child: ErrorDisplay(
                    error: ServiceException(errorMessage),
                    onRetry: () {
                      Navigator.of(context).pop();
                      performLogin(
                        context: context,
                        baseUrl: baseUrl,
                        username: username,
                        password: password,
                        instanceType: instanceType,
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: Icon(Icons.close, color: EVColors.textFieldLabel),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      // Re-throw to be handled by caller
      rethrow;
    }
  }
  
  /// Initializes offline components with user credentials
  Future<void> _initializeOfflineComponents({
    required String instanceType,
    required String baseUrl,
    required String authToken,
    required String username,
  }) async {
    try {
      // Create offline manager without requiring credentials
      final offlineManager = await OfflineManager.createDefault(requireCredentials: false);
      
      // Save credentials
      await offlineManager.saveCredentials(
        instanceType: instanceType,
        baseUrl: baseUrl,
        authToken: authToken,
      );
      
      // Initialize the sync service
      final syncService = SyncService();
      syncService.initialize(
        instanceType: instanceType,
        baseUrl: baseUrl,
        authToken: authToken,
      );
    } catch (e) {
      // Log the error but don't fail login
      print('Error initializing offline components: $e');
    }
  }
  
  /// Checks if the device has offline content available
  Future<bool> hasOfflineContent() async {
    try {
      // Get offline manager
      final offlineManager = await OfflineManager.createDefault();
      
      // Get the list of offline items at the root level
      final items = await offlineManager.getOfflineItems(null);
      
      // If there are any items, offline content is available
      return items.isNotEmpty;
    } catch (e) {
      print('Error checking for offline content: $e');
      return false;
    }
  }
  
  /// Navigates to the offline browse screen
  Future<void> navigateToOfflineBrowse(BuildContext context) async {
    try {
      // Get saved credentials
      final offlineManager = await OfflineManager.createDefault();
      final credentials = await offlineManager.getSavedCredentials();
      
      if (credentials == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot access offline content without logging in first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OfflineBrowseScreen(
              instanceType: credentials['instanceType']!,
              baseUrl: credentials['baseUrl']!,
              authToken: credentials['authToken']!,
              firstName: credentials['firstName'] ?? 'User',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to offline browse: $e');
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