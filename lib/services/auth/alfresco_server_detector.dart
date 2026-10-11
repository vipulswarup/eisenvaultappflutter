import 'dart:convert';

import 'package:http/http.dart' as http;

/// Identifies Alfresco before trying an Angora login on an unknown host.
/// A web frontend can return HTML with status 200 for nonexistent API routes.
Future<bool> isAlfrescoServer(String baseUrl, {http.Client? client}) async {
  try {
    final url = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/alfresco/api/discovery',
    );
    final response = await (client?.get(url) ?? http.get(url)).timeout(
      const Duration(seconds: 5),
    );
    if (response.statusCode == 401) {
      // 5.2 challenges with Basic; 26.1 can challenge with AlfTicket.
      // Recognize the repository realm, rather than the authentication scheme.
      return RegExp(
        r'realm="Alfresco [^"]*"',
        caseSensitive: false,
      ).hasMatch(response.headers['www-authenticate'] ?? '');
    }
    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body);
    return data is Map &&
        data['entry'] is Map &&
        data['entry']['repository'] is Map;
  } catch (_) {
    // Preserve the existing Angora-first fallback if discovery is unavailable.
    return false;
  }
}
