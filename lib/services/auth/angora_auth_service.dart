import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/angora_base_service.dart';
import '../../utils/logger.dart';

/// Service handling authentication for Angora DMS
/// Manages login, token management and user profile retrieval
class AngoraAuthService extends AngoraBaseService {
  AngoraAuthService(super.baseUrl);

  /// Authenticates user with Angora DMS
  /// 
  /// [username] Email address of the user
  /// [password] User's password
  /// 
  /// Returns a Map containing the authentication token and user profile
  /// Throws an Exception if authentication fails
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final loginUrl = buildUrl('auth/login');
      
    
      final payload = {
        'email': username,
        'password': password,
      };
      

      final response = await http.post(
        Uri.parse(loginUrl),
        headers: createHeaders(serviceName: 'service-auth'),
        body: jsonEncode(payload),
      );

      
      EVLogger.debug('Angora login response', {
        'statusCode': response.statusCode,
        'headers': response.headers.toString(),
        'body': response.body,
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        EVLogger.debug('Parsed login response data', {
          'dataKeys': data.keys.toList(),
          'hasData': data.containsKey('data'),
        });
        
        // Validate response structure
        if (data['data'] == null) {
          EVLogger.error('Invalid response structure: missing data field', {
            'response': response.body,
            'parsedData': data,
          });
          throw Exception('Invalid response: missing data field');
        }
        
        // Extract token from cookie header (Angora sends token in set-cookie header)
        // Note: HTTP headers are case-insensitive, so check both 'set-cookie' and 'Set-Cookie'
        String? token;
        final setCookieHeaders = response.headers['set-cookie'] ?? response.headers['Set-Cookie'];
        if (setCookieHeaders != null) {
          // Handle multiple set-cookie headers (can be a list or single string)
          // The http package returns headers as Map<String, String>, so setCookieHeaders is always a String
          final cookieString = setCookieHeaders.toString();
          
          // Parse the accessToken from the set-cookie header
          // Format: accessToken=TOKEN_VALUE; Max-Age=...; Path=...; ...
          // Note: If there are multiple cookies, they're comma-separated
          final cookies = cookieString.split(',');
          for (final cookie in cookies) {
            final trimmedCookie = cookie.trim();
            final accessTokenMatch = RegExp(r'accessToken=([^;]+)').firstMatch(trimmedCookie);
            if (accessTokenMatch != null) {
              token = accessTokenMatch.group(1);
              EVLogger.debug('Token extracted from cookie', {
                'tokenLength': token?.length ?? 0,
                'cookiePreview': trimmedCookie.length > 50 ? trimmedCookie.substring(0, 50) : trimmedCookie,
              });
              break;
            }
          }
        }
        
        // Fallback: try to get token from response body (if API changes)
        if (token == null || token.isEmpty) {
          final tokenFromBody = data['data']['token'];
          if (tokenFromBody != null && tokenFromBody.toString().isNotEmpty) {
            token = tokenFromBody.toString();
            EVLogger.debug('Token extracted from response body', {
              'tokenLength': token.length,
            });
          }
        }
        
        if (token == null || token.isEmpty) {
          EVLogger.error('Token is null or empty', {
            'response': response.body,
            'data': data,
            'setCookieHeader': setCookieHeaders,
            'hasSetCookie': setCookieHeaders != null,
          });
          throw Exception('Authentication failed: token is missing in response');
        }
        
        final user = data['data']['user'];
        if (user == null) {
          EVLogger.error('User profile is null in response', {
            'response': response.body,
            'data': data,
          });
          throw Exception('Authentication failed: user profile is missing in response');
        }
        
        setToken(token);
        EVLogger.debug('Angora login successful', {
          'tokenLength': token.length,
          'hasUser': user != null,
        });
        
        return {
          'token': token,
          'profile': user,
        };
      }
    
      // For non-200 responses, include response body in error for better debugging
      String errorMessage = 'Authentication failed with status code: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = '${errorData['message']} (status: ${response.statusCode})';
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = '${errorData['error']} (status: ${response.statusCode})';
        }
        EVLogger.error('Angora login error response', {
          'statusCode': response.statusCode,
          'body': response.body,
          'parsedError': errorData,
        });
      } catch (e) {
        EVLogger.error('Angora login error (could not parse response)', {
          'statusCode': response.statusCode,
          'body': response.body,
        });
      }
      
      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      EVLogger.error('Login failed', e, stackTrace);
      throw Exception('Login failed: $e');
    }
  }
  
  /// Refreshes the authentication token by re-authenticating with stored credentials
  /// 
  /// [username] Email address of the user
  /// [password] User's password
  /// 
  /// Returns a Map containing the new authentication token and user profile
  /// Throws an Exception if refresh fails
  Future<Map<String, dynamic>> refreshToken(String username, String password) async {
    EVLogger.info('Refreshing Angora authentication token');
    try {
      // Use the same login endpoint to refresh the token
      return await login(username, password);
    } catch (e, stackTrace) {
      EVLogger.error('Token refresh failed', e, stackTrace);
      rethrow;
    }
  }
}