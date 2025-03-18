import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/services/upload/upload_constants.dart';

/// Service for uploading files to Angora repository.
/// Uses AngoraBaseService for API access.
class AngoraUploadService {
  /// The base service for handling common API functionality
  final AngoraBaseService _baseService;
  
  /// Optional callback for progress updates
  final Function(UploadProgress)? onProgressUpdate;
  
  /// Constructor initializes the base service with proper authentication
  AngoraUploadService({
    required String baseUrl,
    required String authToken,
    this.onProgressUpdate,
  }) : _baseService = AngoraBaseService(baseUrl) {
    _baseService.setToken(authToken);
  }

  /// Unified upload method - handles both file paths and bytes
  Future<Map<String, dynamic>> uploadDocument({
    required String parentFolderId,
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    String? description,
  }) async {
    // Validate inputs
    if ((filePath == null && fileBytes == null) ||
        (filePath != null && fileBytes != null)) {
      throw ArgumentError('Exactly one of filePath or fileBytes must be provided');
    }
    
    EVLogger.debug('Upload document to Angora', {
      'parentFolderId': parentFolderId,
      'fileName': fileName,
      'hasPath': filePath != null,
      'hasBytes': fileBytes != null
    });
    
    // Get file bytes if path provided
    Uint8List bytes;
    if (filePath != null) {
      final file = File(filePath);
      bytes = await file.readAsBytes();
      final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
      
      EVLogger.debug('File read from disk', {
        'size': '${bytes.length} bytes', 
        'mimeType': mimeType
      });
      
      return _uploadFileData(
        parentFolderId: parentFolderId,
        fileBytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        description: description,
      );
    } else {
      bytes = fileBytes!;
      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
      
      return _uploadFileData(
        parentFolderId: parentFolderId,
        fileBytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        description: description,
      );
    }
  }
  
  /// Upload a document from a file path (for native platforms)
  /// Kept for backward compatibility
  Future<Map<String, dynamic>> uploadDocumentPath({
    required String parentFolderId,
    required String filePath,
    required String fileName,
    String? description,
  }) async {
    return uploadDocument(
      parentFolderId: parentFolderId,
      filePath: filePath,
      fileName: fileName,
      description: description,
    );
  }
  
  /// Upload a document from bytes (for web platforms)
  /// Kept for backward compatibility
  Future<Map<String, dynamic>> uploadDocumentBytes({
    required String parentFolderId,
    required Uint8List fileBytes,
    required String fileName,
    String? description,
  }) async {
    return uploadDocument(
      parentFolderId: parentFolderId,
      fileBytes: fileBytes,
      fileName: fileName,
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
    
    // Notify of upload start
    _updateProgress(fileId, 0, fileBytes.length, UploadStatus.waiting);
    
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
    baseHeaders['x-portal'] = 'mobile'; // Indicate this is from the mobile app
    
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
      request.fields['comment'] = description;
    }
    
    EVLogger.debug('Angora request fields', {'fields': request.fields});
    
    try {
      EVLogger.debug('Sending Angora multipart upload request', {'files': request.files.length});
      
      // Update progress to in-progress
      _updateProgress(fileId, 0, fileBytes.length, UploadStatus.inProgress);
      
      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          EVLogger.error('Angora request timed out');
          _updateProgress(fileId, 0, fileBytes.length, UploadStatus.failed);
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
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        EVLogger.debug('Angora upload successful', {'response': responseBody});
        _updateProgress(fileId, fileBytes.length, fileBytes.length, UploadStatus.success);
        return jsonDecode(responseBody);
      } else {
        EVLogger.error('Angora upload failed', {
          'status': streamedResponse.statusCode.toString(),
          'response': responseBody
        });
        _updateProgress(fileId, 0, fileBytes.length, UploadStatus.failed);
        throw Exception('Failed to upload document to Angora: ${streamedResponse.statusCode} - $responseBody');
      }
    } catch (e) {
      EVLogger.error('Error during Angora file upload', {'error': e.toString()});
      _updateProgress(fileId, 0, fileBytes.length, UploadStatus.failed);
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
  
  /// Update progress and notify listeners if callback is provided
  void _updateProgress(String fileId, int uploadedBytes, int totalBytes, String status) {
    final progress = UploadProgress(
      fileId: fileId,
      uploadedBytes: uploadedBytes,
      totalBytes: totalBytes,
      status: status,
    );
    
    EVLogger.debug('Upload progress', {
      'fileId': fileId,
      'uploadedBytes': uploadedBytes,
      'totalBytes': totalBytes,
      'status': status,
      'percent': progress.percentComplete.toStringAsFixed(1) + '%',
    });
    
    onProgressUpdate?.call(progress);
  }
}