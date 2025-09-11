import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';
import 'package:eisenvaultappflutter/services/api/base_service.dart';
import 'package:eisenvaultappflutter/services/auth/classic_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/widgets/error_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      
      // Strip known suffixes (e.g., /share/page, /share, /page, /alfresco, /s, trailing slashes)
      baseUrl = _stripUrlSuffixes(baseUrl);
      // For Classic instances, append /alfresco if not present
      if (!baseUrl.endsWith('/alfresco')) {
        baseUrl = '$baseUrl/alfresco';
      }

      // Perform login using Classic auth service
      EVLogger.productionLog('=== LOGIN HANDLER - STARTING LOGIN ===');
      EVLogger.productionLog('Base URL: $baseUrl');
      EVLogger.productionLog('Username: $username');
      EVLogger.productionLog('Instance Type: $instanceType');
      
      final authService = ClassicAuthService(baseUrl);
      EVLogger.productionLog('Auth service created');
      
      final loginResult = await authService.makeRequest(
        'login',
        requestFunction: () => authService.login(username, password)
      );
      
      EVLogger.productionLog('Login successful, token length: ${loginResult['token']?.toString().length ?? 0}');
      EVLogger.productionLog('Login result keys: ${loginResult.keys.toList()}');

      if (!context.mounted) return;
      
      // Extract firstName from the profile
      final firstName = loginResult['profile']?['firstName'] ?? username;
      
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
        firstName: firstName,
        instanceType: instanceType,
        baseUrl: baseUrl,
        customerHostname: customerHostname,
      );
      
      // Save credentials to SharedPreferences for ShareActivity
      EVLogger.productionLog('Saving credentials after successful login');
      await _saveCredentialsToSharedPrefs(
        baseUrl: baseUrl,
        authToken: loginResult['token'],
        instanceType: instanceType,
        customerHostname: customerHostname,
      );
      
      // Initialize offline components and wait for completion
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
              firstName: firstName,
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
              firstName: credentials['firstName'] ?? credentials['username'] ?? 'User',
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

  String _stripUrlSuffixes(String url) {
    // Remove trailing slashes first
    url = url.replaceAll(RegExp(r'/+\u0000'), '');
    // List of known suffixes to strip
    final suffixes = [
      '/share/page',
      '/share',
      '/page',
      '/alfresco',
      '/s',
    ];
    for (final suffix in suffixes) {
      if (url.endsWith(suffix)) {
        url = url.substring(0, url.length - suffix.length);
        // Remove any trailing slashes after removing suffix
        url = url.replaceAll(RegExp(r'/+\u0000'), '');
      }
    }
    // Remove any trailing slashes again
    url = url.replaceAll(RegExp(r'/+\u0000'), '');
    return url;
  }
  
  /// Save credentials to SharedPreferences for ShareActivity access
  Future<void> _saveCredentialsToSharedPrefs({
    required String baseUrl,
    required String authToken,
    required String instanceType,
    required String customerHostname,
  }) async {
    try {
      EVLogger.productionLog('=== SAVING CREDENTIALS TO SHARED PREFERENCES ===');
      EVLogger.productionLog('baseUrl: $baseUrl');
      EVLogger.productionLog('hasAuthToken: ${authToken.isNotEmpty}');
      EVLogger.productionLog('instanceType: $instanceType');
      EVLogger.productionLog('customerHostname: $customerHostname');
      
      const MethodChannel channel = MethodChannel('com.eisenvault.eisenvaultappflutter/main');
      
      await channel.invokeMethod('saveDMSCredentials', {
        'baseUrl': baseUrl,
        'authToken': authToken,
        'instanceType': instanceType,
        'customerHostname': customerHostname,
      });
      
      EVLogger.productionLog('Credentials saved to SharedPreferences successfully');
    } catch (e) {
      EVLogger.error('Failed to save credentials to SharedPreferences', {
        'error': e.toString()
      });
    }
  }
}