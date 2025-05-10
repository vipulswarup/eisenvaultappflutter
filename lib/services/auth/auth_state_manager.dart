import 'package:flutter/foundation.dart';
import 'package:eisenvaultappflutter/services/auth/persistent_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/classic_auth_service.dart';
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
        if (credentials != null) {
          _restoreFromCredentials(credentials);
          _isAuthenticated = true;
          notifyListeners();
        }
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