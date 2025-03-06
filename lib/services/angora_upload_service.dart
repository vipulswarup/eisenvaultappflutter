import 'dart:typed_data';

class AngoraUploadService {
  Future<Map<String, dynamic>> uploadDocument({
    required String parentFolderId,
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    String? description,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Return dummy successful response
    return {
      'entry': {
        'id': 'dummy-${DateTime.now().millisecondsSinceEpoch}',
        'name': fileName,
        'nodeType': 'cm:content',
        'isFile': true,
        'isFolder': false,
        'modifiedAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'content': {
          'mimeType': 'application/octet-stream',
          'sizeInBytes': fileBytes?.length ?? 1024,
        }
      }
    };
  }
}
