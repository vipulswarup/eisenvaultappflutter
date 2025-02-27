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
      EVLogger.info('Attempting Angora login', {'url': loginUrl});
    
      final payload = {
        'email': username,
        'password': password,
      };
      EVLogger.debug('Login payload', payload);

      final response = await http.post(
        Uri.parse(loginUrl),
        headers: createHeaders(serviceName: 'service-auth'),
        body: jsonEncode(payload),
      );

      EVLogger.debug('Response status code', response.statusCode);
      EVLogger.debug('Response body', response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['data']['token'];
        setToken(token);
        
        return {
          'token': token,
          'profile': data['data']['user'],
        };
      }
    
      throw Exception('Authentication failed with status code: ${response.statusCode}');
    } catch (e, stackTrace) {
      EVLogger.error('Login failed', e, stackTrace);
      throw Exception('Login failed: $e');
    }
  }
}