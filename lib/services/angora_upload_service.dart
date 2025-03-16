import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:crypto/crypto.dart';

/// Service for uploading files to Angora repository.
/// Uses AngoraBaseService for API access.
class AngoraUploadService {
  /// The base service for handling common API functionality
  final AngoraBaseService _baseService;
  
  /// Constructor initializes the base service with proper authentication
  AngoraUploadService({
    required String baseUrl,
    required String authToken,
  }) : _baseService = AngoraBaseService(baseUrl) {
    _baseService.setToken(authToken);
  }

  /// Upload a document from a file path (for native platforms)
  Future<Map<String, dynamic>> uploadDocument({
    required String parentFolderId,
    required String filePath,
    required String fileName,
    String? description,
  }) async {
    EVLogger.debug('Upload document to Angora from path', {
      'parentFolderId': parentFolderId,
      'filePath': filePath,
      'fileName': fileName
    });
    
    // Read file from disk
    final file = File(filePath);
    final fileBytes = await file.readAsBytes();
    final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
    
    EVLogger.debug('File read from disk', {
      'size': '${fileBytes.length} bytes', 
      'mimeType': mimeType
    });
    
    return _uploadFileData(
      parentFolderId: parentFolderId,
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
      description: description,
    );
  }
  
  /// Upload a document from bytes (for web platforms)
  Future<Map<String, dynamic>> uploadDocumentBytes({
    required String parentFolderId,
    required Uint8List fileBytes,
    required String fileName,
    String? description,
  }) async {
    EVLogger.debug('Upload document to Angora from bytes', {
      'parentFolderId': parentFolderId,
      'fileName': fileName,
      'size': '${fileBytes.length} bytes'
    });
    
    // Determine MIME type from filename
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    
    return _uploadFileData(
      parentFolderId: parentFolderId,
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
      description: description,
    );
  }
  
  /// Common implementation for uploading file data to Angora
  Future<Map<String, dynamic>> _uploadFileData({
    required String parentFolderId,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    String? description,
  }) async {
    // Build Angora API URL using the base service
    final url = _baseService.buildUrl('uploads');
    
    EVLogger.debug('Creating Angora multipart request', {'url': url});
    
    // Generate a unique file ID for Angora
    final fileId = _generateFileId(parentFolderId, fileName, fileBytes.length);
    
    var request = http.MultipartRequest('POST', Uri.parse(url));
    
    // Add headers for Angora upload
    final baseHeaders = _baseService.createHeaders();
    
    // Add Angora-specific headers
    baseHeaders['Content-Type'] = 'multipart/form-data';
    baseHeaders['x-start-byte'] = '0';
    baseHeaders['x-file-size'] = fileBytes.length.toString();
    baseHeaders['x-relative-path'] = '';
    baseHeaders['x-file-id'] = fileId;
    baseHeaders['x-parent-id'] = parentFolderId;
    baseHeaders['x-resumable'] = 'true';
    baseHeaders['x-file-name'] = fileName;
    
    // Remove Content-Type as it will be set by the multipart request
    baseHeaders.remove('Content-Type');
    
    // Apply all headers to the request
    request.headers.addAll(baseHeaders);
    
    EVLogger.debug('Angora request headers', {'headers': request.headers});
    
    // Add file content as multipart file
    request.files.add(
      http.MultipartFile.fromBytes(
        'file', // Field name for the file
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      )
    );
    
    // Add description as a field if provided
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }
    
    EVLogger.debug('Angora request fields', {'fields': request.fields});
    
    try {
      EVLogger.debug('Sending Angora multipart upload request', {'files': request.files.length});
      
      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          EVLogger.error('Angora request timed out');
          throw TimeoutException('Request timed out');
        }
      );
      
      EVLogger.debug('Angora response received', {
        'status': streamedResponse.statusCode.toString(),
        'headers': streamedResponse.headers
      });
      
      // Read response body
      final responseBody = await streamedResponse.stream.bytesToString();

      // Process response
      if (streamedResponse.statusCode == 200) {
        EVLogger.debug('Angora upload successful', {'response': responseBody});
        return jsonDecode(responseBody);
      } else {
        EVLogger.error('Angora upload failed', {
          'status': streamedResponse.statusCode.toString(),
          'response': responseBody
        });
        throw Exception('Failed to upload document to Angora: ${streamedResponse.statusCode} - $responseBody');
      }
    } catch (e) {
      EVLogger.error('Error during Angora file upload', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Helper method to generate a file ID in the format required by Angora
  String _generateFileId(String parentId, String fileName, int fileSize) {
    // Generate a timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Create a file ID in the format expected by Angora
    return '${parentId}_${fileName}_${fileSize}_$timestamp';
  }
}