import 'base_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Callback type for token refresh
/// Returns the new token if refresh succeeded, null otherwise
/// This allows the service instance to update its token after refresh
typedef TokenRefreshCallback = Future<String?> Function();

class AngoraBaseService extends BaseService {
  String? _token;
  TokenRefreshCallback? _tokenRefreshCallback;
  bool _isRefreshing = false;

  AngoraBaseService(super.baseUrl);

  void setToken(String? token) => _token = token;
  String? getToken() => _token;
  
  /// Set callback for token refresh when 401 is detected
  void setTokenRefreshCallback(TokenRefreshCallback? callback) {
    _tokenRefreshCallback = callback;
  }

  Map<String, String> createHeaders({String? serviceName}) {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Accept-Language': 'en',
      'x-portal': 'web',
    };

    if (_token != null) {
      headers['Authorization'] = _token!;
    }

    if (serviceName != null) {
      headers['x-service-name'] = serviceName;
    }
    
    return headers;
  }

  @override
  String buildUrl(String path) {
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$cleanBaseUrl/api/$cleanPath';
  }
  
  /// Checks if response indicates authentication failure and attempts token refresh
  /// Returns true if token was refreshed, false otherwise
  /// After refresh, updates the token in this service instance
  Future<bool> handleAuthFailure(int statusCode) async {
    if (statusCode == 401 && _tokenRefreshCallback != null && !_isRefreshing) {
      EVLogger.info('401 Unauthorized detected, attempting token refresh');
      _isRefreshing = true;
      try {
        final newToken = await _tokenRefreshCallback!();
        if (newToken != null && newToken.isNotEmpty) {
          // Update token in this service instance
          setToken(newToken);
          EVLogger.info('Token refreshed successfully and updated in service instance');
          return true;
        } else {
          EVLogger.warning('Token refresh failed - no token returned');
          return false;
        }
      } catch (e) {
        EVLogger.error('Error during token refresh', e);
        return false;
      } finally {
        _isRefreshing = false;
      }
    }
    return false;
  }
}
