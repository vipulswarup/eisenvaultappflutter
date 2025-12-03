import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/services.dart';
import 'package:eisenvaultappflutter/services/auth/persistent_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/multi_account_auth_service.dart';
import 'package:eisenvaultappflutter/services/auth/angora_auth_service.dart';
import 'package:eisenvaultappflutter/models/account.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Manages the authentication state of the application
/// This is the single source of truth for authentication state
/// Supports multiple accounts with account switching
class AuthStateManager extends ChangeNotifier {
  static final AuthStateManager _instance = AuthStateManager._internal();
  
  factory AuthStateManager() => _instance;
  
  AuthStateManager._internal();
  
  final PersistentAuthService _persistentAuth = PersistentAuthService();
  final MultiAccountAuthService _multiAccountAuth = MultiAccountAuthService();
  
  bool _isAuthenticated = false;
  Account? _currentAccount;
  List<Account> _allAccounts = [];
  
  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String? get currentToken => _currentAccount?.token;
  String? get instanceType => _currentAccount?.instanceType;
  String? get baseUrl => _currentAccount?.baseUrl;
  String? get username => _currentAccount?.username;
  String? get firstName => _currentAccount?.firstName;
  String? get customerHostname => _currentAccount?.customerHostname;
  Account? get currentAccount => _currentAccount;
  List<Account> get allAccounts => List.unmodifiable(_allAccounts);
  
  /// Initialize the auth state manager
  /// This should be called when the app starts
  Future<void> initialize() async {
    try {
      // Load all accounts
      _allAccounts = await _multiAccountAuth.getAllAccounts();
      
      // Try to get active account
      final activeAccount = await _multiAccountAuth.getActiveAccount();
      
      if (activeAccount != null) {
        _currentAccount = activeAccount;
        _isAuthenticated = true;
        // Update Share Extension credentials
        await _updateShareExtensionCredentials(activeAccount);
      } else if (_allAccounts.isNotEmpty) {
        // If no active account but accounts exist, set the first one as active
        await switchAccount(_allAccounts.first.id);
      } else {
        // Fallback to old single-account storage for migration
        final hasValidCredentials = await _persistentAuth.hasValidCredentials();
        if (hasValidCredentials) {
          final credentials = await _persistentAuth.getStoredCredentials();
          await _migrateOldAccount(credentials);
        }
      }
      
      notifyListeners();
    } catch (e) {
      EVLogger.error('Failed to initialize auth state', e);
      _clearState();
    }
  }
  
  /// Migrate old single-account storage to multi-account
  Future<void> _migrateOldAccount(Map<String, String?> credentials) async {
    try {
      if (credentials['username'] == null || credentials['baseUrl'] == null) {
        return;
      }
      
      final account = Account.fromCredentials(
        username: credentials['username']!,
        firstName: credentials['firstName'] ?? credentials['username']!,
        instanceType: credentials['instanceType'] ?? 'Classic',
        baseUrl: credentials['baseUrl']!,
        customerHostname: credentials['customerHostname'] ?? '',
        token: credentials['token'] ?? '',
        password: credentials['password'],
        tokenExpiry: credentials['tokenExpiry'],
      );
      
      await _multiAccountAuth.addOrUpdateAccount(account);
      await _multiAccountAuth.setActiveAccount(account.id);
      
      _allAccounts = await _multiAccountAuth.getAllAccounts();
      _currentAccount = account;
      _isAuthenticated = true;
      
      // Clear old storage
      await _persistentAuth.clearCredentials();
    } catch (e) {
      EVLogger.error('Failed to migrate old account', e);
    }
  }
  
  /// Handle successful login
  /// Adds or updates the account and sets it as active
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
      // Create account from credentials
      final account = Account.fromCredentials(
        username: username,
        firstName: firstName,
        instanceType: instanceType,
        baseUrl: baseUrl,
        customerHostname: customerHostname,
        token: token,
        password: password,
        tokenExpiry: tokenExpiry,
      );
      
      // Add or update account
      await _multiAccountAuth.addOrUpdateAccount(account);
      
      // Set as active account
      await _multiAccountAuth.setActiveAccount(account.id);
      
      // Reload accounts and update state
      _allAccounts = await _multiAccountAuth.getAllAccounts();
      _currentAccount = account;
      _isAuthenticated = true;
      
      notifyListeners();
      
      // Update Share Extension credentials after notifying listeners
      await _updateShareExtensionCredentials(account);
    } catch (e) {
      EVLogger.error('Failed to handle successful login', e);
      rethrow;
    }
  }
  
  /// Switch to a different account
  Future<bool> switchAccount(String accountId) async {
    try {
      final success = await _multiAccountAuth.setActiveAccount(accountId);
      if (success) {
        _allAccounts = await _multiAccountAuth.getAllAccounts();
        _currentAccount = await _multiAccountAuth.getActiveAccount();
        _isAuthenticated = _currentAccount != null;
        
        // Update Share Extension credentials for the new active account
        if (_currentAccount != null) {
          await _updateShareExtensionCredentials(_currentAccount!);
        }
        
        notifyListeners();
      }
      return success;
    } catch (e) {
      EVLogger.error('Failed to switch account', e);
      return false;
    }
  }
  
  /// Update Share Extension credentials (iOS App Groups)
  Future<void> _updateShareExtensionCredentials(Account account) async {
    try {
      // Import platform check
      if (kIsWeb) return;
      
      // Only update on iOS
      if (Platform.isIOS) {
        const MethodChannel channel = MethodChannel('uploadChannel');
        await channel.invokeMethod('saveDMSCredentials', {
          'baseUrl': account.baseUrl,
          'authToken': account.token,
          'instanceType': account.instanceType,
          'customerHostname': account.customerHostname,
        });
        EVLogger.info('Updated Share Extension credentials for account: ${account.displayName}');
      }
    } catch (e) {
      EVLogger.error('Failed to update Share Extension credentials', e);
    }
  }
  
  /// Remove an account (logout from specific account)
  Future<bool> removeAccount(String accountId) async {
    try {
      final success = await _multiAccountAuth.removeAccount(accountId);
      if (success) {
        _allAccounts = await _multiAccountAuth.getAllAccounts();
        
        // If we removed the current account, update current account
        if (_currentAccount?.id == accountId) {
          _currentAccount = await _multiAccountAuth.getActiveAccount();
          _isAuthenticated = _currentAccount != null;
        }
        
        notifyListeners();
      }
      return success;
    } catch (e) {
      EVLogger.error('Failed to remove account', e);
      return false;
    }
  }
  
  /// Handle logout (removes current account)
  Future<void> logout() async {
    try {
      if (_currentAccount != null) {
        await removeAccount(_currentAccount!.id);
      }
      
      // If no accounts left, clear state
      if (_allAccounts.isEmpty) {
        _clearState();
      }
      
      notifyListeners();
    } catch (e) {
      EVLogger.error('Failed to logout', e);
      rethrow;
    }
  }
  
  /// Logout from all accounts
  Future<void> logoutAll() async {
    try {
      await _multiAccountAuth.clearAllAccounts();
      _clearState();
      notifyListeners();
    } catch (e) {
      EVLogger.error('Failed to logout all', e);
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
      if (_currentAccount == null) {
        EVLogger.warning('Cannot refresh token: no active account');
        return false;
      }
      
      // Only refresh for Angora instances
      if (_currentAccount!.instanceType.toLowerCase() != 'angora') {
        EVLogger.debug('Token refresh not needed for Classic instance');
        return true;
      }
      
      if (_currentAccount!.password == null) {
        EVLogger.warning('Cannot refresh token: password not stored');
        return false;
      }
      
      // Attempt to refresh token
      final authService = AngoraAuthService(_currentAccount!.baseUrl);
      final loginResult = await authService.refreshToken(
        _currentAccount!.username,
        _currentAccount!.password!,
      );
      
      final newToken = loginResult['token'];
      if (newToken == null || newToken.toString().isEmpty) {
        EVLogger.error('Token refresh failed: no token in response');
        return false;
      }
      
      // Update account token
      final tokenExpiry = loginResult['tokenExpiry']?.toString();
      await _multiAccountAuth.updateAccountToken(
        _currentAccount!.id,
        newToken.toString(),
        tokenExpiry: tokenExpiry,
      );
      
      // Reload accounts to get updated token
      _allAccounts = await _multiAccountAuth.getAllAccounts();
      _currentAccount = await _multiAccountAuth.getActiveAccount();
      
      EVLogger.info('Token refreshed successfully');
      notifyListeners();
      
      return true;
    } catch (e) {
      EVLogger.error('Failed to refresh token', e);
      return false;
    }
  }
  
  /// Clear the current state
  void _clearState() {
    _isAuthenticated = false;
    _currentAccount = null;
    _allAccounts = [];
  }
} 