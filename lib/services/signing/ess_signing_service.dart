import 'dart:convert';

import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/models/signing/signing_session.dart';
import 'package:eisenvaultappflutter/services/signing/signing_eligibility.dart';
import 'package:eisenvaultappflutter/services/signing/signing_service.dart';
import 'package:eisenvaultappflutter/utils/http_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;

class EssSigningService implements SigningService {
  final String baseUrl;
  final String alfrescoTicket;
  final http.Client? client;

  EssSigningService({
    required this.baseUrl,
    required this.alfrescoTicket,
    this.client,
  });

  static const startPath = 'api/v1/mobile/signing/start';
  static const statusPathTemplate =
      'api/v1/mobile/signing/sessions/{sessionId}/status';
  static const cancelPathTemplate =
      'api/v1/mobile/signing/sessions/{sessionId}/cancel';

  @override
  Future<SigningSession> startSigning({
    required BrowseItem document,
    required String repositoryBaseUrl,
    required String returnUrl,
  }) async {
    _validateMobileTicket();

    final response = await _postJson(startPath, {
      'repositoryType': 'alfresco',
      'repositoryBaseUrl': _normalizeRepositoryBaseUrl(repositoryBaseUrl),
      'documentId': document.id,
      'fileName': document.name,
      'mimeType': SigningEligibility.mimeTypeFor(document.name),
      'returnUrl': returnUrl,
      'clientReturnUrl': returnUrl,
      'clientSource': 'flutter',
    });

    _throwIfError(response);
    return SigningSession.fromJson(_decodeJson(response));
  }

  @override
  Future<SigningSessionStatus> getStatus(String sessionId) async {
    _validateMobileTicket();
    final path = statusPathTemplate.replaceAll(
      '{sessionId}',
      Uri.encodeComponent(sessionId),
    );
    final response = await _get(path);
    _throwIfError(response);
    return SigningSessionStatus.fromJson(_decodeJson(response));
  }

  @override
  Future<void> cancelSigning(String sessionId) async {
    _validateMobileTicket();
    final path = cancelPathTemplate.replaceAll(
      '{sessionId}',
      Uri.encodeComponent(sessionId),
    );
    final response = await _postJson(path, const {});
    if (response.statusCode == 404) return;
    _throwIfError(response);
  }

  Future<http.Response> _get(String path) {
    final uri = _buildUri(path);
    _logRequest('GET', path);
    if (client != null) {
      return client!
          .get(uri, headers: _headers())
          .timeout(apiRequestTimeout)
          .then((response) {
            _logResponse('GET', path, response);
            return response;
          });
    }
    return getWithTimeout(uri, headers: _headers()).then((response) {
      _logResponse('GET', path, response);
      return response;
    });
  }

  Future<http.Response> _postJson(String path, Map<String, dynamic> body) {
    final uri = _buildUri(path);
    final encodedBody = jsonEncode(body);
    _logRequest('POST', path);
    if (client != null) {
      return client!
          .post(uri, headers: _headers(), body: encodedBody)
          .timeout(apiRequestTimeout)
          .then((response) {
            _logResponse('POST', path, response);
            return response;
          });
    }
    return http
        .post(uri, headers: _headers(), body: encodedBody)
        .timeout(apiRequestTimeout)
        .then((response) {
          _logResponse('POST', path, response);
          return response;
        });
  }

  Uri _buildUri(String path) {
    final cleanBase =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$cleanBase/$cleanPath');
  }

  String _normalizeRepositoryBaseUrl(String value) {
    final uri = Uri.parse(value.trim());
    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.toLowerCase().endsWith('/alfresco')) {
      path = path.substring(0, path.length - '/alfresco'.length);
    }
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: path,
    ).toString().replaceFirst(RegExp(r'/+$'), '');
  }

  Map<String, String> _headers() {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $alfrescoTicket',
    };
  }

  void _validateMobileTicket() {
    final ticket = alfrescoTicket.trim();
    final normalized = ticket.toLowerCase();
    if (ticket.isEmpty || normalized.startsWith('basic ')) {
      EVLogger.productionLog('ESS request blocked', {
        'operation': 'mobile_signing',
        'reason':
            ticket.isEmpty
                ? 'alfresco_ticket_missing'
                : 'classic_basic_auth_is_not_mobile_safe',
      });
      throw const SigningResponseException(
        'Sign in again to obtain an Alfresco ticket for mobile signing.',
      );
    }
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through to a safe user-facing error below.
    }
    throw const SigningResponseException(
      'Signing service returned an invalid response.',
    );
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    var message = _messageForStatus(response.statusCode);
    String? code;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          code = error['code']?.toString();
          message = (error['message'] ?? error['code'] ?? message).toString();
        } else {
          code = decoded['code']?.toString();
          message =
              (decoded['message'] ?? decoded['code'] ?? message).toString();
        }
      }
    } catch (_) {
      // Keep the generic message; do not expose raw service responses.
    }

    throw SigningResponseException(_messageForCode(code, message));
  }

  void _logRequest(String method, String path) {
    final uri = Uri.tryParse(baseUrl);
    EVLogger.productionLog('ESS request', {
      'method': method,
      'host': uri?.host ?? 'invalid',
      'path': '/${path.replaceFirst(RegExp(r'^/+'), '')}',
    });
  }

  void _logResponse(String method, String path, http.Response response) {
    String? code;
    String? message;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        code = decoded['code']?.toString();
        message = decoded['message']?.toString();
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          code ??= error['code']?.toString();
          message ??= error['message']?.toString();
        }
      }
    } catch (_) {
      // Never print raw HTML or non-JSON responses.
    }

    final safeMessage = _safeLogMessage(message);
    EVLogger.productionLog('ESS response', {
      'method': method,
      'path': '/${path.replaceFirst(RegExp(r'^/+'), '')}',
      'statusCode': response.statusCode,
      if (code != null) 'code': code,
      if (safeMessage != null) 'message': safeMessage,
    });
  }

  String _messageForCode(String? code, String fallback) {
    switch (code?.toUpperCase()) {
      case 'MOBILE_AUTH_REQUIRED':
      case 'BASIC_AUTH_NOT_ALLOWED':
      case 'INVALID_REPOSITORY_SESSION':
        return 'Your repository session has expired. Sign in again.';
      case 'TENANT_NOT_FOUND':
        return 'OpenSign is not configured for this repository.';
      case 'DOCUMENT_NOT_FOUND':
        return 'The document could not be found.';
      case 'PERMISSION_DENIED':
        return 'You do not have permission to sign this document.';
      case 'UNSUPPORTED_FILE_TYPE':
        return 'This file type cannot be signed.';
      case 'USER_PROFILE_INCOMPLETE':
        return 'Complete your signing profile before signing.';
      case 'SESSION_ALREADY_EXISTS':
        return 'A signing session is already active for this document.';
      case 'SESSION_NOT_FOUND':
        return 'The signing session could not be found.';
      case 'SESSION_NOT_OWNED':
        return 'This signing session belongs to another user.';
      case 'INVALID_RETURN_URL':
        return 'The signing callback is not configured correctly.';
      case 'OPENSIGN_UNAVAILABLE':
        return 'OpenSign is temporarily unavailable.';
      case 'REPOSITORY_UNAVAILABLE':
        return 'The repository is temporarily unavailable.';
      default:
        return fallback;
    }
  }

  String? _safeLogMessage(String? message) {
    if (message == null || message.isEmpty) return null;
    final normalized = message.toLowerCase();
    if (normalized.contains('http://') ||
        normalized.contains('https://') ||
        normalized.contains('authorization') ||
        normalized.contains('ticket_')) {
      return null;
    }
    return message.length <= 240 ? message : '${message.substring(0, 240)}...';
  }

  String _messageForStatus(int statusCode) {
    switch (statusCode) {
      case 401:
      case 403:
        return 'The signing service rejected authentication for this account.';
      case 404:
        return 'The signing service endpoint was not found. Check the ESS URL for this account.';
      case 408:
      case 504:
        return 'The signing service timed out. Please try again.';
      default:
        if (statusCode >= 500) {
          return 'The signing service is temporarily unavailable.';
        }
        return 'Signing could not be started.';
    }
  }
}
