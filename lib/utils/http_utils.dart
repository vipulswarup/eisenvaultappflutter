import 'package:http/http.dart' as http;

/// Shared HTTP client so requests to the same host reuse connections.
final http.Client appHttpClient = http.Client();

const Duration apiRequestTimeout = Duration(seconds: 30);
const Duration downloadRequestTimeout = Duration(seconds: 90);

const _maxAttempts = 3;

bool _isRetryableError(Object error) {
  if (error is http.ClientException) {
    final message = error.message.toLowerCase();
    return message.contains('connection closed') ||
        message.contains('connection reset') ||
        message.contains('broken pipe');
  }
  return false;
}

Future<http.Response> _sendWithRetry(
  Future<http.Response> Function(http.Client client) send,
) async {
  Object? lastError;

  for (var attempt = 0; attempt < _maxAttempts; attempt++) {
    final useSharedClient = attempt == 0;
    final client = useSharedClient ? appHttpClient : http.Client();

    try {
      final response = await send(client);
      if (!useSharedClient) {
        client.close();
      }
      return response;
    } catch (error) {
      if (!useSharedClient) {
        client.close();
      }
      lastError = error;
      if (!_isRetryableError(error) || attempt == _maxAttempts - 1) {
        rethrow;
      }
    }
  }

  throw lastError ?? Exception('Request failed');
}

Future<http.Response> getWithTimeout(
  Uri url, {
  Map<String, String>? headers,
  Duration timeout = apiRequestTimeout,
}) {
  return _sendWithRetry(
    (client) => client.get(url, headers: headers).timeout(
      timeout,
      onTimeout: () => throw Exception(
        'Request timed out after ${timeout.inSeconds}s',
      ),
    ),
  );
}

Future<http.Response> headWithTimeout(
  Uri url, {
  Map<String, String>? headers,
  Duration timeout = apiRequestTimeout,
}) {
  return _sendWithRetry(
    (client) => client.head(url, headers: headers).timeout(
      timeout,
      onTimeout: () => throw Exception(
        'Request timed out after ${timeout.inSeconds}s',
      ),
    ),
  );
}
