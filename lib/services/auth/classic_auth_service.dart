import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/classic_base_service.dart';

class ClassicAuthService extends ClassicBaseService {
  ClassicAuthService(super.baseUrl);

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      final basicAuth = 'Basic $credentials';
      
      final response = await http.post(
        Uri.parse(buildUrl('api/-default-/public/authentication/versions/1/tickets')),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': username,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final profileResponse = await http.get(
          Uri.parse(buildUrl('api/-default-/public/alfresco/versions/1/people/-me-')),
          headers: {'Authorization': basicAuth},
        );

        if (profileResponse.statusCode == 200) {
          return {
            'token': basicAuth,
            'profile': jsonDecode(profileResponse.body)['entry'],
          };
        }
      }
      
      throw Exception('Authentication failed');
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }
}
