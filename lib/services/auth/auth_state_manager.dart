import 'package:flutter/foundation.dart';
import 'package:eisenvaultappflutter/services/auth/persistent_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Manages the authentication state of the application
/// This is the single source of truth for authentication state
class AuthStateManager extends ChangeNotifier {
  static final AuthStateManager _instance = AuthStateManager._internal();
  
  factory AuthStateManager() => _instance;
  
  AuthStateManager._internal();
  
  final PersistentAuthService _persistentAuth = PersistentAuthService();
  
  bool _isAuthenticated = false;
  String? _currentToken;
  String? _instanceType;
  String? _baseUrl;
  String? _username;
  String? _firstName;
  String? _customerHostname;
  
  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String? get currentToken => _currentToken;
  String? get instanceType => _instanceType;
  String? get baseUrl => _baseUrl;
  String? get username => _username;
  String? get firstName => _firstName;
  String? get customerHostname => _customerHostname;
  
  /// Initialize the auth state manager
  /// This should be called when the app starts
  Future<void> initialize() async {
    try {
      final hasValidCredentials = await _persistentAuth.hasValidCredentials();
      if (hasValidCredentials) {
        final credentials = await _persistentAuth.getStoredCredentials();
        _restoreFromCredentials(credentials);
        _isAuthenticated = true;
        notifyListeners();
            }
    } catch (e) {
      EVLogger.error('Failed to initialize auth state', e);
      _clearState();
    }
  }
  
  /// Handle successful login
  Future<void> handleSuccessfulLogin({
    required String token,
    required String username,
    required String firstName,
    required String instanceType,
    required String baseUrl,
    required String customerHostname,
    String? tokenExpiry,
    String? password,
  }) async {
    try {
      // Store credentials
      await _persistentAuth.storeCredentials(
        token: token,
        username: username,
        firstName: firstName,
        instanceType: instanceType,
        baseUrl: baseUrl,
        customerHostname: customerHostname,
        tokenExpiry: tokenExpiry,
        password: password, // Store password for Angora token refresh
      );
      
      // Update state
      _currentToken = token;
      _username = username;
      _firstName = firstName;
      _instanceType = instanceType;
      _baseUrl = baseUrl;
      _customerHostname = customerHostname;
      _isAuthenticated = true;
      
      notifyListeners();
    } catch (e) {
      EVLogger.error('Failed to handle successful login', e);
      rethrow;
    }
  }
  
  /// Handle logout
  Future<void> logout() async {
    try {
      await _persistentAuth.clearCredentials();
      _clearState();
      notifyListeners();
    } catch (e) {
      EVLogger.error('Failed to logout', e);
      rethrow;
    }
  }
  
  /// Refresh the authentication token
  /// 
  /// Attempts to refresh the token using stored credentials.
  /// Only works for Angora instances. Classic instances don't need refresh.
  /// Returns true if refresh was successful, false otherwise.
  Future<bool> refreshToken() async {
    try {
      // Only refresh for Angora instances
      if (_instanceType?.toLowerCase() != 'angora') {
        EVLogger.debug('Token refresh not needed for Classic instance');
        return true;
      }
      
      // Get stored credentials
      final credentials = await _persistentAuth.getStoredCredentials();
      final username = credentials['username'];
      final password = credentials['password'];
      final baseUrl = credentials['baseUrl'];
      
      if (username == null || password == null || baseUrl == null) {
        EVLogger.warning('Cannot refresh token: missing credentials');
        return false;
      }
      
      // Attempt to refresh token
      final authService = AngoraAuthService(baseUrl);
      final loginResult = await authService.refreshToken(username, password);
      
      final newToken = loginResult['token'];
      if (newToken == null || newToken.toString().isEmpty) {
        EVLogger.error('Token refresh failed: no token in response');
        return false;
      }
      
      // Update stored credentials with new token
      await _persistentAuth.storeCredentials(
        token: newToken.toString(),
        username: username,
        firstName: credentials['firstName'] ?? _firstName ?? username,
        instanceType: _instanceType!,
        baseUrl: baseUrl,
        customerHostname: credentials['customerHostname'] ?? _customerHostname ?? '',
        password: password,
        tokenExpiry: credentials['tokenExpiry'],
      );
      
      // Update state
      _currentToken = newToken.toString();
      _isAuthenticated = true;
      
      EVLogger.info('Token refreshed successfully');
      notifyListeners();
      
      return true;
    } catch (e) {
      EVLogger.error('Failed to refresh token', e);
      return false;
    }
  }
  
  /// Restore state from stored credentials
  void _restoreFromCredentials(Map<String, String?> credentials) {
    _currentToken = credentials['token'];
    _username = credentials['username'];
    _firstName = credentials['firstName'];
    _instanceType = credentials['instanceType'];
    _baseUrl = credentials['baseUrl'];
    _customerHostname = credentials['customerHostname'];
  }
  
  /// Clear the current state
  void _clearState() {
    _isAuthenticated = false;
    _currentToken = null;
    _username = null;
    _firstName = null;
    _instanceType = null;
    _baseUrl = null;
    _customerHostname = null;
  }
} 