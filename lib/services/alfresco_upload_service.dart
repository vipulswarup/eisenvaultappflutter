import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class AlfrescoUploadService {
  final String baseUrl;
  final String authToken;

  AlfrescoUploadService({
    required this.baseUrl,
    required this.authToken,
  });

  Future<Map<String, dynamic>> uploadDocument({
    required String parentFolderId,
    required String filePath,
    required String fileName,
    String? description,
  }) async {
    final url = '$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$parentFolderId/children';
    
    final file = File(filePath);
    final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
    final fileBytes = await file.readAsBytes();

    var request = http.MultipartRequest('POST', Uri.parse(url));
    
    // Add authorization header
    request.headers['Authorization'] = 'Basic $authToken';
    
    // Add file content
    request.files.add(
      http.MultipartFile.fromBytes(
        'filedata',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      )
    );

    // Add metadata
    request.fields['nodeType'] = 'cm:content';
    request.fields['name'] = fileName;
    if (description != null && description.isNotEmpty) {
      request.fields['cm:description'] = description;
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to upload document: $responseBody');
    }
  }
}
