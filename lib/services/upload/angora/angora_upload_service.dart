import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:eisenvaultappflutter/models/upload/batch_upload_models.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/upload/base/upload_service.dart';
import 'package:eisenvaultappflutter/services/upload/base/upload_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Angora-specific implementation of the upload service.
/// 
/// This class handles uploads to the Angora DMS backend, including:
/// - Chunked uploading for large files
/// - Angora-specific headers and API requirements
/// - Progress tracking and reporting
class AngoraUploadService extends BaseUploadService {
  /// The base service for handling API communication
  final AngoraBaseService _baseService;
  
  /// Maximum number of retry attempts for failed uploads
  static const int _maxRetries = 3;
  
  /// Default timeout for upload operations in seconds
  static const int _uploadTimeoutSeconds = 30;
  
  /// Constructor initializes the base service with authentication
  AngoraUploadService({
    required String baseUrl,
    required String authToken,
    Function(UploadProgress)? onProgressUpdate,
  }) : _baseService = AngoraBaseService(baseUrl),
       super(onProgressUpdate: onProgressUpdate) {
    _baseService.setToken(authToken);
  }
  
  /// Angora supports chunked uploads for large files
  @override
  bool get supportsChunkedUpload => true;
  
  /// Angora supports resumable uploads (can continue partial uploads)
  @override
  bool get supportsResumableUpload => true;
  
  /// Maximum file size for a single upload (100MB for Angora)
  /// This is used to determine when to switch to chunked uploading
  @override
  int get maxUploadSizeBytes => 100 * 1024 * 1024; // 100 MB
  
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
      
      // Generate a unique file ID
      final fileId = generateFileId(parentFolderId, fileName, bytes.length);
      
      // Sanitize filename to ensure compatibility
      final sanitizedFileName = UploadUtils.sanitizeFileName(fileName);
      
      // Decide whether to use chunked or simple upload based on file size
      if (bytes.length > 5 * 1024 * 1024) { // 5 MB threshold
        return _uploadLargeFile(
          parentFolderId: parentFolderId,
          fileId: fileId,
          fileName: sanitizedFileName,
          fileBytes: bytes,
          mimeType: mimeType,
          description: description,
        );
      } else {
        return _uploadSmallFile(
          parentFolderId: parentFolderId,
          fileId: fileId,
          fileName: sanitizedFileName, 
          fileBytes: bytes,
          mimeType: mimeType,
          description: description,
        );
      }
    } catch (e) {
      EVLogger.error('Error preparing upload', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Upload a small file in a single request
  Future<Map<String, dynamic>> _uploadSmallFile({
    required String parentFolderId,
    required String fileId,
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
    String? description,
  }) async {
    // Notify of upload start
    updateProgress(fileId, 0, fileBytes.length, UploadStatus.waiting);
    
    try {
      // Build API URL
      final url = _baseService.buildUrl('uploads');
      
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add Angora-specific headers
      final baseHeaders = _baseService.createHeaders();
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
      
      // Apply headers to the request
      request.headers.addAll(baseHeaders);
      
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
      
      // Update progress to in-progress
      updateProgress(fileId, 0, fileBytes.length, UploadStatus.inProgress);
      
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
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        // Update progress to success
        updateProgress(fileId, fileBytes.length, fileBytes.length, UploadStatus.success);
      
        return jsonDecode(responseBody);
      } else {
        // Update progress to failed
        updateProgress(fileId, 0, fileBytes.length, UploadStatus.failed);
        
        EVLogger.error('Upload failed', {
          'status': streamedResponse.statusCode,
          'response': responseBody
        });
        
        throw Exception('Failed to upload document: ${streamedResponse.statusCode} - $responseBody');
      }
    } catch (e) {
      // Handle upload error
      handleUploadError(fileId, fileBytes.length, e);
      rethrow;
    }
  }
  
  /// Upload a large file in chunks
  Future<Map<String, dynamic>> _uploadLargeFile({
    required String parentFolderId,
    required String fileId,
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
    String? description,
  }) async {
    // Notify of upload start
    updateProgress(fileId, 0, fileBytes.length, UploadStatus.waiting);
    
    // Split file into chunks
    final chunks = UploadUtils.splitIntoChunks(
      fileId: fileId,
      fileName: fileName,
      fileBytes: fileBytes,
    );

    
    // Upload each chunk with retry logic
    Map<String, dynamic>? finalResponse;
    int uploadedBytes = 0;
    
    try {
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        
        // Update progress
        updateProgress(fileId, uploadedBytes, fileBytes.length, UploadStatus.inProgress);
        
        bool chunkUploaded = false;
        int retryCount = 0;
        
        // Try uploading this chunk with retries
        while (!chunkUploaded && retryCount <= _maxRetries) {
          try {
            final response = await _uploadChunk(
              parentFolderId: parentFolderId,
              fileId: fileId,
              fileName: fileName,
              chunk: chunk,
              mimeType: mimeType,
              description: i == 0 ? description : null, // Only include description with first chunk
            );
            
            // Chunk uploaded successfully
            chunkUploaded = true;
            finalResponse = response;
            uploadedBytes = chunk.endByte;
            
            // Small delay between chunks
            if (i < chunks.length - 1) {
              await Future.delayed(const Duration(milliseconds: 300));
            }
          } catch (e) {
            retryCount++;
            EVLogger.error('Error uploading chunk', {
              'fileId': fileId,
              'chunkIndex': i,
              'retryCount': retryCount,
              'error': e.toString(),
            });
            
            if (retryCount > _maxRetries) {
              throw Exception('Maximum retry attempts reached. Upload failed.');
            }
            
            // Wait before retry with exponential backoff
            await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          }
        }
      }
      
      // All chunks uploaded successfully
      updateProgress(fileId, fileBytes.length, fileBytes.length, UploadStatus.success);
      
      return finalResponse ?? {'success': true, 'id': fileId};
    } catch (e) {
      // Handle upload error
      handleUploadError(fileId, fileBytes.length, e);
      rethrow;
    }
  }
  
  /// Upload a single chunk to the server
  Future<Map<String, dynamic>> _uploadChunk({
    required String parentFolderId,
    required String fileId,
    required String fileName,
    required FileChunk chunk,
    required String mimeType,
    String? description,
  }) async {
    // Build API URL
    final url = _baseService.buildUrl('uploads');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', Uri.parse(url));
    
    // Add headers
    final headers = _baseService.createHeaders();
    headers.remove('Content-Type'); // Will be set by multipart
    
    // Add Angora upload-specific headers
    headers['x-file-id'] = fileId;
    headers['x-file-name'] = fileName;
    headers['x-start-byte'] = chunk.startByte.toString();
    headers['x-file-size'] = chunk.totalFileSize.toString();
    headers['x-resumable'] = 'true';
    headers['x-relative-path'] = '';
    headers['x-parent-id'] = parentFolderId;
    headers['x-portal'] = 'mobile'; // Indicate this is from the mobile app
    
    request.headers.addAll(headers);
    
    // Add file chunk
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        chunk.data,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      )
    );
    
    // Add description as comment if provided
    if (description != null && description.isNotEmpty) {
      request.fields['comment'] = description;
    }
    
    // Send the request with timeout
    final streamedResponse = await request.send().timeout(
      Duration(seconds: _uploadTimeoutSeconds),
      onTimeout: () {
        throw TimeoutException('Chunk upload timed out');
      }
    );
    
    // Read response
    final responseBody = await streamedResponse.stream.bytesToString();
    
    // Check response status
    if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Chunk upload failed: ${streamedResponse.statusCode}');
    }
  }
}
