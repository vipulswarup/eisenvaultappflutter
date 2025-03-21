import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:eisenvaultappflutter/models/upload/upload_progress.dart';
import 'package:eisenvaultappflutter/services/api/classic_base_service.dart';
import 'package:eisenvaultappflutter/services/upload/base/upload_service.dart';
import 'package:eisenvaultappflutter/services/upload/base/upload_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Alfresco/Classic-specific implementation of the upload service.
/// 
/// This class handles uploads to the Classic Alfresco DMS backend, including:
/// - Single-file uploads (no chunking in Alfresco's public API)
/// - Alfresco-specific headers and API requirements
/// - Progress tracking and reporting
class AlfrescoUploadService extends BaseUploadService {
  /// The base service for handling API communication
  final ClassicBaseService _baseService;
  
  /// Default timeout for upload operations in seconds
  static const int _uploadTimeoutSeconds = 30;
  
  /// Constructor initializes the base service with authentication
  AlfrescoUploadService({
    required String baseUrl,
    required String authToken,
    Function(UploadProgress)? onProgressUpdate,
  }) : _baseService = ClassicBaseService(baseUrl),
       super(onProgressUpdate: onProgressUpdate) {
    // Ensure the token has the 'Basic ' prefix if it doesn't already
    final token = authToken.startsWith('Basic ') ? authToken : 'Basic $authToken';
    _baseService.setToken(token);
  }
  
  /// Alfresco doesn't support chunked uploads in its public API
  @override
  bool get supportsChunkedUpload => false;
  
  /// Alfresco doesn't support resumable uploads
  @override
  bool get supportsResumableUpload => false;
  
  /// Maximum file size for a single upload (50MB for Alfresco)
  /// This is a practical limit for direct uploads
  @override
  int get maxUploadSizeBytes => 50 * 1024 * 1024; // 50 MB
  
  @override
  Future<Map<String, dynamic>> uploadDocument({
    required String parentFolderId,
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    String? description,
    Function(UploadProgress)? onProgressUpdate,
  }) async {
    // Validate inputs using shared method from base class
    validateUploadInputs(filePath: filePath, fileBytes: fileBytes);
    
    // If onProgressUpdate is provided, use it instead of the class level one
    final progressCallback = onProgressUpdate ?? super.onProgressUpdate;
    
    EVLogger.debug('Upload document to Alfresco', {
      'parentFolderId': parentFolderId,
      'fileName': fileName,
      'hasPath': filePath != null,
      'hasBytes': fileBytes != null
    });
    
    try {
      // Get file bytes if path provided
      Uint8List bytes;
      if (filePath != null) {
        final file = File(filePath);
        bytes = await file.readAsBytes();
      } else {
        bytes = fileBytes!;
      }
      
      // Determine MIME type
      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
      
      // Generate a file ID for progress tracking (won't be sent to Alfresco)
      final fileId = generateFileId(parentFolderId, fileName, bytes.length);
      
      // Sanitize filename to ensure compatibility
      final sanitizedFileName = UploadUtils.sanitizeFileName(fileName);
      
      // Perform the upload
      return _uploadFileToAlfresco(
        fileId: fileId,  
        parentFolderId: parentFolderId,
        fileBytes: bytes,
        fileName: sanitizedFileName,
        mimeType: mimeType,
        description: description,
        onProgressUpdate: progressCallback,
      );
    } catch (e) {
      EVLogger.error('Error preparing upload', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Upload a file to the Alfresco repository
  Future<Map<String, dynamic>> _uploadFileToAlfresco({
    required String fileId,
    required String parentFolderId,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    String? description,
    Function(UploadProgress)? onProgressUpdate,
  }) async {
    // Notify of upload start
    _updateProgress(
      fileId, 
      0, 
      fileBytes.length, 
      UploadStatus.waiting, 
      onProgressUpdate
    );
    
    try {
      // Build Alfresco API URL manually to ensure correct format
      final baseUrl = _baseService.baseUrl;
      final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final url = '$cleanBaseUrl/api/-default-/public/alfresco/versions/1/nodes/$parentFolderId/children';
      
      EVLogger.debug('Creating Alfresco upload request', {'url': url});
      
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add headers using the base service
      final baseHeaders = _baseService.createHeaders();
      baseHeaders.remove('Content-Type'); // Will be set by multipart
      request.headers.addAll(baseHeaders);
      
      EVLogger.debug('Request headers', {'headers': request.headers});
      
      // Update progress to in-progress
      _updateProgress(
        fileId,
        0, 
        fileBytes.length, 
        UploadStatus.inProgress, 
        onProgressUpdate
      );
      
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
      
      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        Duration(seconds: _uploadTimeoutSeconds),
        onTimeout: () {
          throw TimeoutException('Upload request timed out');
        }
      );
      
      // Read response body
      final responseBody = await streamedResponse.stream.bytesToString();
      
      // Process response
      if (streamedResponse.statusCode == 201) {
        // Update progress to success
        _updateProgress(
          fileId, 
          fileBytes.length, 
          fileBytes.length, 
          UploadStatus.success, 
          onProgressUpdate
        );
        
        EVLogger.debug('Upload successful', {
          'fileId': fileId, 
          'status': streamedResponse.statusCode
        });
        
        return jsonDecode(responseBody);
      } else {
        // Update progress to failed
        _updateProgress(
          fileId, 
          0, 
          fileBytes.length, 
          UploadStatus.failed, 
          onProgressUpdate
        );
        
        EVLogger.error('Upload failed', {
          'status': streamedResponse.statusCode,
          'response': responseBody
        });
        
        throw Exception('Failed to upload document: ${streamedResponse.statusCode} - $responseBody');
      }
    } catch (e) {
      // Handle upload error
      _handleUploadError(fileId, fileBytes.length, e, onProgressUpdate);
      rethrow;
    }
  }
  
  /// Helper method to update progress
  void _updateProgress(
    String fileId, 
    int uploadedBytes, 
    int totalBytes, 
    String status,
    Function(UploadProgress)? progressCallback
  ) {
    final progress = UploadProgress(
      fileId: fileId,
      uploadedBytes: uploadedBytes,
      totalBytes: totalBytes,
      status: status,
    );
    
    if (progressCallback != null) {
      progressCallback(progress);
    } else {
      // Use the superclass method
      super.updateProgress(fileId, uploadedBytes, totalBytes, status);
    }
  }
  
  /// Helper method to handle upload errors
  void _handleUploadError(
    String fileId, 
    int totalBytes, 
    dynamic error,
    Function(UploadProgress)? progressCallback
  ) {
    EVLogger.error('Upload error', {'fileId': fileId, 'error': error.toString()});
    
    // Update progress to failed state
    _updateProgress(fileId, 0, totalBytes, UploadStatus.failed, progressCallback);
  }
  
  /// Check if a node exists and has a particular aspect
  Future<bool> checkNodeExists(String nodeId) async {
    try {
      final url = _baseService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$nodeId');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _baseService.createHeaders(),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      EVLogger.error('Error checking node existence', {'nodeId': nodeId, 'error': e.toString()});
      return false;
    }
  }
}
