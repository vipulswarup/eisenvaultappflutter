import 'package:http/http.dart' as http;

/// Only an explicit authentication rejection invalidates a saved session.
/// Network failures leave offline access available.
Future<bool> isClassicSessionRejected(
  String baseUrl,
  String token, {
  http.Client? client,
}) async {
  try {
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r"/+$"), "")}/api/-default-/public/alfresco/versions/1/people/-me-',
    );
    final response = await (client?.get(
              uri,
              headers: {'Authorization': token},
            ) ??
            http.get(uri, headers: {'Authorization': token}))
        .timeout(const Duration(seconds: 10));
    return response.statusCode == 401;
  } catch (_) {
    return false;
  }
}
