import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen.dart';
import 'package:eisenvaultappflutter/screens/offline/offline_browse_screen.dart';
import 'package:eisenvaultappflutter/services/api/base_service.dart';
import 'package:eisenvaultappflutter/services/auth/classic_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/widgets/error_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
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
    // Preserve original baseUrl for error retry
    final originalBaseUrl = baseUrl;
    
    try {
      // Detect instance type from URL if not explicitly provided or if it's 'Classic' (legacy default)
      String detectedInstanceType = instanceType;
      if (instanceType == 'Classic' || instanceType.isEmpty) {
        detectedInstanceType = _detectInstanceType(baseUrl);
      }
      
      // Strip known suffixes (e.g., /share/page, /share, /page, /alfresco, /s, trailing slashes)
      baseUrl = _stripUrlSuffixes(baseUrl);
      
      // Handle URL formatting based on instance type
      String customerHostname;
      bool shouldTryBoth = false;
      final uri = Uri.parse(baseUrl);
      final hostname = uri.host.toLowerCase();
      
      if (detectedInstanceType.toLowerCase() == 'angora') {
        // Angora: Use base URL as-is, extract customer hostname from domain
        customerHostname = uri.host;
      } else {
        // detectedInstanceType is 'Classic' - check if domain contains "angora"
        if (hostname.contains('angora')) {
          // Domain has "angora" but was detected as Classic (shouldn't happen, but handle it)
          // Treat as Classic with /alfresco suffix
          if (!baseUrl.endsWith('/alfresco')) {
            baseUrl = '$baseUrl/alfresco';
          }
          customerHostname = 'classic-repository';
        } else {
          // Domain doesn't contain "angora" - might be custom Angora domain
          // Try Angora first, fall back to Classic if endpoint not found
          shouldTryBoth = true;
          customerHostname = uri.host; // Set for Angora attempt
        }
      }

      // Perform login using appropriate auth service
      EVLogger.productionLog('=== LOGIN HANDLER - STARTING LOGIN ===');
      EVLogger.productionLog('Base URL: $baseUrl');
      EVLogger.productionLog('Username: $username');
      EVLogger.productionLog('Instance Type: $detectedInstanceType');
      EVLogger.productionLog('Customer Hostname: $customerHostname');
      EVLogger.productionLog('Should try both: $shouldTryBoth');
      
      Map<String, dynamic> loginResult;
      
      if (detectedInstanceType.toLowerCase() == 'angora' && !shouldTryBoth) {
        // Confident it's Angora (domain contains "angora")
        final authService = AngoraAuthService(baseUrl);
        EVLogger.productionLog('Angora auth service created');
        
        loginResult = await authService.login(username, password);
        detectedInstanceType = 'Angora';
      } else if (shouldTryBoth) {
        // Unknown domain - try Angora first, fall back to Classic if endpoint not found
        EVLogger.productionLog('Trying Angora login first (unknown domain)');
        try {
          final angoraAuthService = AngoraAuthService(baseUrl);
          loginResult = await angoraAuthService.login(username, password);
          detectedInstanceType = 'Angora';
          EVLogger.productionLog('Angora login successful');
        } catch (e) {
          // Check if error indicates endpoint doesn't exist or wrong API format
          // 404 means endpoint doesn't exist (should try Classic)
          // 400 can mean:
          //   - Wrong endpoint/API format (should try Classic)
          //   - Invalid credentials (should NOT try Classic, show auth error)
          // We need to check the error message to distinguish
          final errorStr = e.toString().toLowerCase();
          
          // Check for clear endpoint errors (404, route not found, etc.)
          final isEndpointNotFound = 
              errorStr.contains('status code: 404') ||
              errorStr.contains('status code 404') ||
              (errorStr.contains('404') && (errorStr.contains('status') || errorStr.contains('authentication failed'))) ||
              errorStr.contains('not found') ||
              errorStr.contains('route not found') ||
              errorStr.contains('endpoint not found') ||
              (e is http.ClientException && (errorStr.contains('failed host lookup') || errorStr.contains('connection refused')));
          
          // Check for 400 errors that indicate wrong endpoint (not auth errors)
          final is400EndpointError = 
              (errorStr.contains('status code: 400') || errorStr.contains('status code 400') || errorStr.contains('status: 400')) &&
              (errorStr.contains('route') || errorStr.contains('endpoint') || errorStr.contains('not found') || errorStr.contains('invalid path'));
          
          // Check for auth-related errors (should NOT fall back to Classic)
          final isAuthError = 
              errorStr.contains('invalid credentials') ||
              errorStr.contains('authentication failed') ||
              errorStr.contains('unauthorized') ||
              errorStr.contains('invalid email') ||
              errorStr.contains('invalid password') ||
              errorStr.contains('user not found') ||
              errorStr.contains('incorrect password');
          
          if (isEndpointNotFound || is400EndpointError) {
            // Endpoint doesn't exist or wrong API format, try Classic
            final statusCode = errorStr.contains('400') ? '400' : '404';
            EVLogger.productionLog('Angora endpoint returned $statusCode (endpoint error), trying Classic');
            if (!baseUrl.endsWith('/alfresco')) {
              baseUrl = '$baseUrl/alfresco';
            }
            customerHostname = 'classic-repository';
            final classicAuthService = ClassicAuthService(baseUrl);
            EVLogger.productionLog('Classic auth service created');
            
            loginResult = await classicAuthService.makeRequest(
              'login',
              requestFunction: () => classicAuthService.login(username, password)
            );
            detectedInstanceType = 'Classic';
          } else if (isAuthError) {
            // Authentication error - don't fall back, show the error
            EVLogger.productionLog('Angora login failed with authentication error, not falling back to Classic');
            rethrow;
          } else {
            // Unknown error - for 400, be conservative and don't fall back (might be auth issue)
            // Only fall back for 404 or connection errors
            if (errorStr.contains('status code: 400') || errorStr.contains('status code 400') || errorStr.contains('status: 400')) {
              EVLogger.productionLog('Angora login returned 400 (unknown reason), not falling back - might be auth issue');
              rethrow;
            } else {
              EVLogger.productionLog('Angora login failed with unknown error, not falling back');
              rethrow;
            }
          }
        }
      } else {
        // Confident it's Classic
        if (!baseUrl.endsWith('/alfresco')) {
          baseUrl = '$baseUrl/alfresco';
        }
        customerHostname = 'classic-repository';
        final authService = ClassicAuthService(baseUrl);
        EVLogger.productionLog('Classic auth service created');
        
        loginResult = await authService.makeRequest(
          'login',
          requestFunction: () => authService.login(username, password)
        );
        detectedInstanceType = 'Classic';
      }
      
      // Validate token is present and not null
      final token = loginResult['token'];
      if (token == null || token.toString().isEmpty) {
        throw Exception('Login failed: authentication token is missing from response');
      }
      
      final tokenString = token.toString();
      EVLogger.productionLog('Login successful, token length: ${tokenString.length}');
      EVLogger.productionLog('Login result keys: ${loginResult.keys.toList()}');

      if (!context.mounted) return;
      
      // Extract firstName from the profile
      final firstName = loginResult['profile']?['firstName'] ?? 
                       loginResult['profile']?['name']?.split(' ').first ?? 
                       username;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login Successful!'),
          backgroundColor: EVColors.alertSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Update auth state
      final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
      await authStateManager.handleSuccessfulLogin(
        token: tokenString,
        username: username,
        firstName: firstName,
        instanceType: detectedInstanceType,
        baseUrl: baseUrl,
        customerHostname: customerHostname,
      );
      
      // Save credentials to SharedPreferences for ShareActivity
      EVLogger.productionLog('Saving credentials after successful login');
      await _saveCredentialsToSharedPrefs(
        baseUrl: baseUrl,
        authToken: tokenString,
        instanceType: detectedInstanceType,
        customerHostname: customerHostname,
      );
      
      // Initialize offline components and wait for completion
      await _initializeOfflineComponents(
        instanceType: detectedInstanceType,
        baseUrl: baseUrl,
        authToken: tokenString,
        username: username,
      );

      // Navigate to browse screen
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => BrowseScreen(
              baseUrl: baseUrl,
              authToken: tokenString,
              firstName: firstName,
              instanceType: detectedInstanceType,
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
      
      // Detect instance type for error retry
      final detectedInstanceType = _detectInstanceType(originalBaseUrl);
      
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
                        baseUrl: originalBaseUrl,
                        username: username,
                        password: password,
                        instanceType: detectedInstanceType,
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
  
  /// Detects instance type from URL based on domain patterns
  String _detectInstanceType(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      final hostname = uri.host.toLowerCase();
      
      // Check if domain contains "angora"
      if (hostname.contains('angora')) {
        return 'Angora';
      }
      
      // Default to Classic
      return 'Classic';
    } catch (e) {
      // If URL parsing fails, default to Classic
      return 'Classic';
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