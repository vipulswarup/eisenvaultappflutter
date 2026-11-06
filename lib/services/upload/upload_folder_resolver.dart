import 'dart:convert';
import 'package:http/http.dart' as http;

/// Creates destination folders once per upload session, including on retries.
/// Existing server name conflicts are reported instead of overwriting content.
class UploadFolderResolver {
  final String repositoryType;
  final String baseUrl;
  final String authToken;
  final String parentFolderId;
  final http.Client _client;
  final Map<String, Future<String>> _folders = {};

  UploadFolderResolver({
    required this.repositoryType,
    required this.baseUrl,
    required this.authToken,
    required this.parentFolderId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<String> resolve(String relativePath) async {
    if (relativePath.isEmpty) return parentFolderId;
    final segments = relativePath.split('/');
    if (segments.any(
      (s) => s.isEmpty || s == '.' || s == '..' || s.contains('\\'),
    )) {
      throw ArgumentError('Invalid destination folder path');
    }
    final existing = _folders[relativePath];
    if (existing != null) return existing;
    final pending = _create(segments);
    _folders[relativePath] = pending;
    try {
      return await pending;
    } catch (_) {
      _folders.remove(relativePath);
      rethrow;
    }
  }

  Future<String> _create(List<String> segments) async {
    final parent = await resolve(segments.take(segments.length - 1).join('/'));
    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final angora = repositoryType.toLowerCase() == 'angora';
    final response = await _client
        .post(
          Uri.parse(
            angora
                ? '$base/api/folders'
                : '$base/api/-default-/public/alfresco/versions/1/nodes/${Uri.encodeComponent(parent)}/children',
          ),
          headers: {
            'Authorization': authToken,
            'Content-Type': 'application/json',
            if (angora) ...{
              'x-portal': 'web',
              'x-service-name': 'service-file',
            },
          },
          body: jsonEncode(
            angora
                ? {'name': segments.last, 'parent_id': parent}
                : {'name': segments.last, 'nodeType': 'cm:folder'},
          ),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Could not create ${segments.join('/')} (HTTP ${response.statusCode}). '
        'A folder with this name may already exist, or access may be denied.',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final dynamic entry = body['entry'] ?? body['data'] ?? body;
    final dynamic id =
        entry is Map ? (entry['id'] ?? entry['folder']?['id']) : null;
    if (id == null || id.toString().isEmpty) {
      throw const FormatException('Folder response did not include an ID');
    }
    return id.toString();
  }

  void dispose() => _client.close();
}
