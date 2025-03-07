import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:eisenvaultappflutter/services/api/classic_base_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Service for uploading files to Alfresco repository.
/// Uses ClassicBaseService for API access but customizes URL building for Alfresco API.
class AlfrescoUploadService {
  /// The base service for handling common API functionality
  final ClassicBaseService _baseService;
  
  /// Constructor initializes the base service with proper authentication
  AlfrescoUploadService({
    required String baseUrl,
    required String authToken,
  }) : _baseService = ClassicBaseService(baseUrl) {
    // Ensure the token has the 'Basic ' prefix if it doesn't already
    final token = authToken.startsWith('Basic ') ? authToken : 'Basic $authToken';
    _baseService.setToken(token);
  }

  /// Upload a document from a file path (for native platforms)
  Future<Map<String, dynamic>> uploadDocument({
    required String parentFolderId,
    required String filePath,
    required String fileName,
    String? description,
  }) async {
    EVLogger.debug('Upload document from path', {
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
    EVLogger.debug('Upload document from bytes', {
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
  
  /// Common implementation for uploading file data to Alfresco
  Future<Map<String, dynamic>> _uploadFileData({
    required String parentFolderId,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    String? description,
  }) async {
    // Build Alfresco API URL manually instead of using _baseService.buildUrl
    // This ensures correct URL format for Alfresco API
    final baseUrl = _baseService.baseUrl;
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = '$cleanBaseUrl/api/-default-/public/alfresco/versions/1/nodes/$parentFolderId/children';
    
    EVLogger.debug('Creating multipart request', {'url': url});
    
    var request = http.MultipartRequest('POST', Uri.parse(url));
    
    // Add headers using the base service
    final baseHeaders = _baseService.createHeaders();
    
    // Remove Content-Type from baseHeaders as it will be set by the multipart request
    baseHeaders.remove('Content-Type');
    
    // Apply all headers to the request
    request.headers.addAll(baseHeaders);
    
    EVLogger.debug('Request headers', {'headers': request.headers});
    
    // Add file content as multipart file
    request.files.add(
      http.MultipartFile.fromBytes(
        'filedata', // Important: must be 'filedata' for Alfresco
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      )
    );

    // Add required metadata fields
    request.fields['name'] = fileName;
    request.fields['nodeType'] = 'cm:content';
    
    // Add optional metadata fields
    if (description != null && description.isNotEmpty) {
      request.fields['cm:description'] = description;
    }
    
    // Add options for automatic rename of existing files
    request.fields['autoRename'] = 'true';
    
    // Request doclib rendition generation
    request.fields['renditions'] = 'doclib';
    
    EVLogger.debug('Request fields', {'fields': request.fields});
    
    // New Debug: Add detailed request information
    EVLogger.debug('Request details', {
      'method': request.method,
      'url': request.url.toString(),
      'fields count': request.fields.length,
      'files count': request.files.length,
    });

    // New Debug: Log before making API call
    EVLogger.debug('About to make API call', {
      'url': url,
      'fileName': fileName,
      'parentFolderId': parentFolderId,
      'fileBytes size': fileBytes.length,
      'token prefix': _baseService.getToken()?.substring(0, 10) // Just show prefix for security
    });
    
    try {
      EVLogger.debug('Sending multipart upload request', {'files': request.files.length});
      
      // New Debug: Enhanced error catching for HTTP request
      try {
        EVLogger.debug('Sending request', {'url': request.url.toString()});
        
        // Send request with timeout
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            EVLogger.error('Request timed out');
            throw TimeoutException('Request timed out');
          }
        );
        
        EVLogger.debug('Response received', {
          'status': streamedResponse.statusCode.toString(),
          'headers': streamedResponse.headers
        });
        
        // Read response body
        final responseBody = await streamedResponse.stream.bytesToString();

        // Process response
        if (streamedResponse.statusCode == 201) {
          EVLogger.debug('Upload successful', {'response': responseBody});
          return jsonDecode(responseBody);
        } else {
          EVLogger.error('Upload failed', {
            'status': streamedResponse.statusCode.toString(),
            'response': responseBody
          });
          throw Exception('Failed to upload document: ${streamedResponse.statusCode} - $responseBody');
        }
      } catch (httpError) {
        EVLogger.error('HTTP request failed', {
          'error': httpError.toString(), 
          'stack': httpError is Error ? httpError.stackTrace.toString() : 'No stack'
        });
        rethrow;
      }
    } catch (e) {
      EVLogger.error('Error during file upload', {'error': e.toString()});
      rethrow;
    }
  }
}
