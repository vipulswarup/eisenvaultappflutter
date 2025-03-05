import 'dart:async';
import 'dart:io';

/// Types of service errors that can occur
enum ServiceErrorType {
  connectivity,  // Network/connection issues
  timeout,       // Request timeout
  unknown        // Other unspecified errors
}

/// Custom exception class for service-related errors
class ServiceException implements Exception {
  final String message;
  final ServiceErrorType type;
  final dynamic originalError;

  ServiceException(
    this.message, {
    this.type = ServiceErrorType.unknown,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Base class for all services
abstract class BaseService {
  final String baseUrl;

  BaseService(this.baseUrl) {
    if (baseUrl.isEmpty) {
      throw Exception('BaseUrl is required for service initialization');
    }
    _validateBaseUrl(baseUrl);
  }

  void _validateBaseUrl(String url) {
    try {
      Uri.parse(url);
    } catch (e) {
      throw Exception('Invalid base URL provided: $url');
    }
  }

  /// Build complete URL from base URL and path
  String buildUrl(String path);

  /// Generic request handler with error handling
  Future<T> makeRequest<T>(String endpoint, {
    required Future<T> Function() requestFunction,
  }) async {
    try {
      return await requestFunction();
    } on SocketException {
      throw ServiceException(
        'Unable to reach server at systest.eisenvault.net\nPlease check if the server is running or try again later.',
        type: ServiceErrorType.connectivity
      );
    } on TimeoutException {
      throw ServiceException(
        'Connection timed out while trying to reach the server.\nThe server may be down or experiencing issues.',
        type: ServiceErrorType.timeout
      );
    } catch (e) {
      final message = e.toString().contains('CORS')
        ? 'Server connection blocked by browser security (CORS).\nPlease contact support if this persists.'
        : 'Unexpected error while connecting to server: ${e.toString()}';
      
      throw ServiceException(
        message,
        type: ServiceErrorType.unknown,
        originalError: e
      );
    }
  }
}
