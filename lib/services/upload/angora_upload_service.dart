import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/upload/angora_chunk_uploader.dart';
import 'package:eisenvaultappflutter/services/upload/angora_upload_utils.dart';
import 'package:eisenvaultappflutter/services/upload/upload_constants.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Service for uploading files to Angora repository.
/// Implements chunking and resumable upload logic following Angora API.
class AngoraUploadService {
  final AngoraBaseService? _baseService;
  late final AngoraChunkUploader? _chunkUploader;
  
  /// Optional callback for progress updates
  final Function(UploadProgress progress)? onProgressUpdate;
  
  /// Constructor with optional base service and progress callback
  AngoraUploadService({
    String? baseUrl, 
    String? authToken, 
    this.onProgressUpdate
  }) : _baseService = (baseUrl != null && authToken != null)
          ? AngoraBaseService(baseUrl)
          : null {
    if (_baseService != null && authToken != null) {
      _baseService!.setToken(authToken);
      _chunkUploader = AngoraChunkUploader(_baseService!);
    } else {
      _chunkUploader = null;
    }
  }

  /// Main upload method - handles both file paths and bytes
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
    
    // In dummy mode, return fake success after delay
    if (_baseService == null || _chunkUploader == null) {
      EVLogger.info('Using dummy Angora upload service');
      await Future.delayed(const Duration(milliseconds: 1500));
      return {'success': true, 'id': 'dummy-${DateTime.now().millisecondsSinceEpoch}'};
    }
    
    // Generate a unique file ID
    final fileId = AngoraUploadUtils.generateFileId(parentFolderId, fileName);
    
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
      
      // Report waiting status
      _updateProgress(fileId, 0, bytes.length, UploadStatus.waiting);
      
      // Upload the file in chunks
      return await _uploadFileInChunks(
        parentFolderId: parentFolderId,
        fileId: fileId,
        fileName: fileName,
        fileBytes: bytes,
        mimeType: mimeType,
        description: description,
      );
    } catch (e) {
      EVLogger.error('Upload failed', {
        'fileId': fileId,
        'error': e.toString()
      });
      _updateProgress(fileId, 0, 0, UploadStatus.failed);
      rethrow;
    }
  }
  
  /// Handle the chunked upload process
  Future<Map<String, dynamic>> _uploadFileInChunks({
    required String parentFolderId,
    required String fileId,
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
    String? description,
  }) async {
    // Check for resumable upload
    int startByte = 0;
    try {
      startByte = await _chunkUploader!.checkUploadStatus(fileId);
      if (startByte > 0) {
        EVLogger.info('Resuming upload from byte $startByte', {
          'fileId': fileId,
          'fileName': fileName
        });
      }
    } catch (e) {
      EVLogger.error('Could not check upload status, starting from beginning', {
        'error': e.toString()
      });
      startByte = 0;
    }
    
    // If the file is already fully uploaded, we're done
    if (startByte >= fileBytes.length) {
      _updateProgress(fileId, fileBytes.length, fileBytes.length, UploadStatus.success);
      return {'success': true, 'id': fileId, 'message': 'File already fully uploaded'};
    }
    
    // Get chunks for upload
    final chunks = AngoraUploadUtils.splitIntoChunks(
      fileId: fileId,
      fileName: fileName,
      fileBytes: fileBytes,
    );
    
    // Skip chunks that are already uploaded
    final remainingChunks = chunks.where((chunk) => 
        chunk.startByte + chunk.data.length > startByte).toList();
    
    // Upload each chunk with retry logic
    Map<String, dynamic>? finalResponse;
    int uploadedBytes = startByte;
    
    for (final chunk in remainingChunks) {
      _updateProgress(fileId, uploadedBytes, fileBytes.length, UploadStatus.inProgress);
      
      // Try uploading this chunk (with retries)
      bool chunkUploaded = false;
      int retryCount = 0;
      
      while (!chunkUploaded && retryCount <= UploadConstants.maxRetries) {
        try {
          final response = await _chunkUploader!.uploadChunk(
            parentFolderId: parentFolderId,
            fileId: fileId,
            fileName: fileName,
            chunk: chunk.data,
            startByte: chunk.startByte,
            totalFileSize: fileBytes.length,
            mimeType: mimeType,
            description: description,
          );
          
          // Chunk uploaded successfully
          chunkUploaded = true;
          finalResponse = response;
          uploadedBytes = (chunk.startByte + chunk.data.length).toInt();
          
          // Small delay between chunks
          if (chunk != remainingChunks.last) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        } catch (e) {
          retryCount++;
          EVLogger.error('Error uploading chunk', {
            'fileId': fileId,
            'startByte': chunk.startByte,
            'retryCount': retryCount,
            'error': e.toString(),
          });
          
          if (retryCount > UploadConstants.maxRetries) {
            _updateProgress(fileId, uploadedBytes, fileBytes.length, UploadStatus.failed);
            throw Exception('Maximum retry attempts reached. Upload failed.');
          }
          
          // Wait before retry with exponential backoff
          await Future.delayed(Duration(milliseconds: 
              (UploadConstants.retryDelayMs * retryCount).toInt()));
        }
      }
    }
    
    // All chunks uploaded successfully
    _updateProgress(fileId, fileBytes.length, fileBytes.length, UploadStatus.success);
    return finalResponse ?? {'success': true, 'id': fileId};
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
