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

  /// Maximum retry attempts for transient failures.
  static const int _maxRetries = 2;

  /// Generic request handler with error handling and retry for transient errors.
  ///
  /// Retries up to [_maxRetries] times with exponential backoff on
  /// [SocketException] and [TimeoutException]. Non-transient errors are thrown
  /// immediately.
  Future<T> makeRequest<T>(String endpoint, {
    required Future<T> Function() requestFunction,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await requestFunction();
      } on SocketException {
        attempt++;
        if (attempt > _maxRetries) {
          throw ServiceException(
            'Unable to reach the server.\nPlease check if the server is running or try again later.',
            type: ServiceErrorType.connectivity,
          );
        }
        await Future.delayed(Duration(milliseconds: 500 * (1 << (attempt - 1))));
      } on TimeoutException {
        attempt++;
        if (attempt > _maxRetries) {
          throw ServiceException(
            'Connection timed out while trying to reach the server.\nThe server may be down or experiencing issues.',
            type: ServiceErrorType.timeout,
          );
        }
        await Future.delayed(Duration(milliseconds: 500 * (1 << (attempt - 1))));
      } catch (e) {
        final message = e.toString().contains('CORS')
          ? 'Server connection blocked by browser security (CORS).\nPlease contact support if this persists.'
          : 'Unexpected error while connecting to server: ${e.toString()}';

        throw ServiceException(
          message,
          type: ServiceErrorType.unknown,
          originalError: e,
        );
      }
    }
  }
}
