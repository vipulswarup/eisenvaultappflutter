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
        String? token;
        final setCookieHeaders = response.headers['set-cookie'];
        if (setCookieHeaders != null) {
          // Parse the accessToken from the set-cookie header
          // Format: accessToken=TOKEN_VALUE; Max-Age=...; Path=...; ...
          final cookieString = setCookieHeaders;
          final accessTokenMatch = RegExp(r'accessToken=([^;]+)').firstMatch(cookieString);
          if (accessTokenMatch != null) {
            token = accessTokenMatch.group(1);
            EVLogger.debug('Token extracted from cookie', {
              'tokenLength': token?.length ?? 0,
            });
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
    
      throw Exception('Authentication failed with status code: ${response.statusCode}');
    } catch (e, stackTrace) {
      EVLogger.error('Login failed', e, stackTrace);
      throw Exception('Login failed: $e');
    }
  }
}