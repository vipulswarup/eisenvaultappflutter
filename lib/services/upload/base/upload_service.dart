import 'dart:async';
import 'dart:typed_data';
import 'package:eisenvaultappflutter/models/upload/batch_upload_models.dart';
import 'package:eisenvaultappflutter/services/upload/base/upload_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Base interface for upload services
abstract class BaseUploadService {
  /// Callback for progress updates
  final Function(UploadProgress)? onProgressUpdate;
  
  /// Constructor that accepts a progress update callback
  BaseUploadService({this.onProgressUpdate});
  
  /// Upload a document to the repository
  Future<Map<String, dynamic>> uploadDocument({
    required String parentFolderId,
    required String fileName,
    String? filePath,
    Uint8List? fileBytes,
    String? description,
    Function(UploadProgress)? onProgressUpdate,
  });
  
  /// Check if chunked upload is supported by this service
  bool get supportsChunkedUpload;
  
  /// Check if resumable upload is supported by this service
  bool get supportsResumableUpload;
  
  /// Get the maximum size for a single upload
  int get maxUploadSizeBytes;
  
  /// Helper method to validate upload inputs
  void validateUploadInputs({String? filePath, Uint8List? fileBytes}) {
    if ((filePath == null && fileBytes == null) ||
        (filePath != null && fileBytes != null)) {
      throw ArgumentError('Exactly one of filePath or fileBytes must be provided');
    }
  }
  
  /// Update progress and notify listeners if callback is provided
  void updateProgress(String fileId, int uploadedBytes, int totalBytes, String status) {
    final progress = UploadProgress(
      fileId: fileId,
      uploadedBytes: uploadedBytes,
      totalBytes: totalBytes,
      status: status,
    );
  
    
    // Notify listeners using the class property
    onProgressUpdate?.call(progress);
  }
  
  /// Generate a unique file ID for tracking uploads
  String generateFileId(String parentId, String fileName, int fileSize) {
    return UploadUtils.generateFileId(parentId, fileName, fileSize);
  }
  
  /// Handles common upload error patterns
  void handleUploadError(String fileId, int totalBytes, dynamic error) {
    EVLogger.error('Upload error', {'fileId': fileId, 'error': error.toString()});
    
    // Update progress to failed state
    updateProgress(fileId, 0, totalBytes, 'failed');
    
    // Rethrow to allow caller to handle
    throw error;
  }
}
