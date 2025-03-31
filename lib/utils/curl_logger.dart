import 'package:http/http.dart' as http;

/// Converts an HTTP request to a CURL command string for debugging
class CurlLogger {
  /// Generate a CURL command from request parameters
  static String toCurlCommand({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
  }) {
    final StringBuffer curl = StringBuffer();
    curl.write('curl -X $method "$url" \\\n');

    // Add headers
    headers.forEach((key, value) {
      curl.write('  -H "$key: $value" \\\n');
    });

    // Add body if present
    if (body != null && body.isNotEmpty) {
      curl.write('  -d \'$body\'');
    } else {
      // Remove the trailing backslash from the last header
      String current = curl.toString();
      curl.clear();
      curl.write(current.substring(0, current.length - 2));
    }

    return curl.toString();
  }

  /// Generate a CURL command from an http.Request
  static String fromRequest(http.BaseRequest request) {
    final StringBuffer curl = StringBuffer();
    curl.write('curl -X ${request.method} "${request.url}" \\\n');

    // Add headers
    request.headers.forEach((key, value) {
      curl.write('  -H "$key: $value" \\\n');
    });

    // Add body if present
    if (request is http.Request && request.body.isNotEmpty) {
      curl.write('  -d \'${request.body}\'');
    } else {
      // Remove the trailing backslash from the last header
      String current = curl.toString();
      curl.clear();
      curl.write(current.substring(0, current.length - 2));
    }

    return curl.toString();
  }
}
