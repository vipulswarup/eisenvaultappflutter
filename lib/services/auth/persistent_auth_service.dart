import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Service to persist authentication credentials for offline access
/// 
/// This service stores authentication tokens and related information
/// securely using flutter_secure_storage, enabling app access without
/// requiring re-authentication when offline.
class PersistentAuthService {
  // Instance of secure storage for storing sensitive auth data
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Keys for stored values
  static const String _tokenKey = 'auth_token';
  static const String _usernameKey = 'username';
  static const String _firstNameKey = 'first_name';
  static const String _instanceTypeKey = 'instance_type';
  static const String _baseUrlKey = 'base_url';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _customerHostnameKey = 'customer_hostname';
  
  /// Stores user credentials securely
  /// 
  /// Saves authentication data for future offline access
  Future<void> storeCredentials({
    required String token,
    required String username,
    required String firstName,
    required String instanceType,
    required String baseUrl,
    required String customerHostname,
    String? tokenExpiry,
  }) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _usernameKey, value: username);
      await _storage.write(key: _firstNameKey, value: firstName);
      await _storage.write(key: _instanceTypeKey, value: instanceType);
      await _storage.write(key: _baseUrlKey, value: baseUrl);
      await _storage.write(key: _customerHostnameKey, value: customerHostname);
      
      // Store token expiry if provided (for JWT tokens)
      if (tokenExpiry != null) {
        await _storage.write(key: _tokenExpiryKey, value: tokenExpiry);
      }
      
      EVLogger.info('Credentials stored successfully for offline access');
    } catch (e) {
      EVLogger.error('Failed to store credentials', e);
      rethrow;
    }
  }
  
  /// Retrieves stored credentials
  /// 
  /// Returns a map containing all stored authentication data or null values
  /// if specific entries aren't found
  Future<Map<String, String?>> getStoredCredentials() async {
    try {
      return {
        'token': await _storage.read(key: _tokenKey),
        'username': await _storage.read(key: _usernameKey),
        'firstName': await _storage.read(key: _firstNameKey),
        'instanceType': await _storage.read(key: _instanceTypeKey),
        'baseUrl': await _storage.read(key: _baseUrlKey),
        'customerHostname': await _storage.read(key: _customerHostnameKey),
        'tokenExpiry': await _storage.read(key: _tokenExpiryKey),
      };
    } catch (e) {
      EVLogger.error('Failed to retrieve stored credentials', e);
      return {};
    }
  }
  
  /// Checks if valid credentials exist
  /// 
  /// Verifies that required credentials are stored and the token
  /// has not expired (if expiry information is available)
  Future<bool> hasValidCredentials() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final baseUrl = await _storage.read(key: _baseUrlKey);
      final instanceType = await _storage.read(key: _instanceTypeKey);
      
      // Check if essential credentials exist
      if (token == null || baseUrl == null || instanceType == null) {
        return false;
      }
      
      // Check token expiry if available
      final tokenExpiry = await _storage.read(key: _tokenExpiryKey);
      if (tokenExpiry != null) {
        final expiryDate = DateTime.parse(tokenExpiry);
        if (DateTime.now().isAfter(expiryDate)) {
          EVLogger.info('Stored token has expired');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      EVLogger.error('Error checking credential validity', e);
      return false;
    }
  }
  
  /// Clears all stored credentials
  /// 
  /// Used during logout to remove all authentication data
  Future<void> clearCredentials() async {
    try {
      await _storage.deleteAll();
      EVLogger.info('All credentials cleared');
    } catch (e) {
      EVLogger.error('Failed to clear credentials', e);
      rethrow;
    }
  }
}