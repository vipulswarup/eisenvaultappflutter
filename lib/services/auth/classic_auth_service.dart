import 'dart:convert';

import 'package:eisenvaultappflutter/utils/http_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;

import '../api/classic_base_service.dart';

class ClassicAuthService extends ClassicBaseService {
  static const _signingConfigPath = 's/ev/signing/config';
  static const _discoveryTimeout = Duration(seconds: 5);

  final http.Client? client;

  ClassicAuthService(super.baseUrl, {this.client});

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      final basicAuth = 'Basic $credentials';
      final response = await _post(
        Uri.parse(
          buildUrl('api/-default-/public/authentication/versions/1/tickets'),
        ),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userId': username, 'password': password}),
      );
      EVLogger.productionLog('Classic ticket login response', {
        'statusCode': response.statusCode,
      });

      if (response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final ticket = decoded['entry']?['id']?.toString();
        if (ticket == null || ticket.isEmpty) {
          throw Exception('Authentication ticket is missing');
        }

        final ticketAuthorization =
            'Basic ${base64Encode(utf8.encode(ticket))}';
        final profileResponse = await _get(
          Uri.parse(
            buildUrl('api/-default-/public/alfresco/versions/1/people/-me-'),
          ),
          headers: {'Authorization': ticketAuthorization},
        );
        EVLogger.productionLog('Classic profile response', {
          'statusCode': profileResponse.statusCode,
        });

        if (profileResponse.statusCode == 200) {
          final essBaseUrl = await _discoverEssBaseUrl(ticketAuthorization);
          return {
            'token': ticketAuthorization,
            'alfrescoTicket': ticket,
            'profile': jsonDecode(profileResponse.body)['entry'],
            if (essBaseUrl != null) 'essBaseUrl': essBaseUrl,
          };
        }
      }

      throw Exception('Authentication failed');
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<String?> _discoverEssBaseUrl(String ticketAuthorization) async {
    try {
      final response = await _get(
        Uri.parse(buildUrl(_signingConfigPath)),
        headers: {'Authorization': ticketAuthorization},
        timeout: _discoveryTimeout,
      );
      EVLogger.productionLog('Classic signing config discovery response', {
        'statusCode': response.statusCode,
      });
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['enabled'] != true) return null;

      final value = decoded['essBaseUrl']?.toString().trim();
      if (value == null || value.isEmpty) return null;

      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        EVLogger.productionLog('Classic signing config discovery ignored', {
          'reason': 'invalid_ess_url',
        });
        return null;
      }

      final normalized = value.replaceFirst(RegExp(r'/+$'), '');
      EVLogger.productionLog('Classic signing config discovered', {
        'configured': true,
      });
      return normalized;
    } catch (error) {
      EVLogger.debug('Classic signing config discovery unavailable', {
        'errorType': error.runtimeType.toString(),
      });
      return null;
    }
  }

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, String> headers,
    required Object body,
  }) {
    final request =
        client?.post(uri, headers: headers, body: body) ??
        http.post(uri, headers: headers, body: body);
    return request.timeout(apiRequestTimeout);
  }

  Future<http.Response> _get(
    Uri uri, {
    required Map<String, String> headers,
    Duration timeout = apiRequestTimeout,
  }) {
    final request =
        client?.get(uri, headers: headers) ?? http.get(uri, headers: headers);
    return request.timeout(timeout);
  }
}
