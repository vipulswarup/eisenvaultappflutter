import 'dart:async';
import 'dart:typed_data';
import 'package:eisenvaultappflutter/services/upload/upload_constants.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Represents a file to be uploaded
class UploadFileItem {
  final String name;
  final String? path;
  final Uint8List? bytes;
  String? id; // Added for tracking
  String? errorMessage; // Add this to store error details
  
  UploadFileItem({
    required this.name,
    this.path,
    this.bytes,
    this.id,
    this.errorMessage,
  });
  
  // Create a copy of this item with an error message
  UploadFileItem copyWithError(String error) {
    return UploadFileItem(
      name: name,
      path: path,
      bytes: bytes,
      id: id,
      errorMessage: error,
    );
  }
}

/// Progress information for a batch upload
class BatchUploadProgress {
  final int totalFiles;
  final int completedFiles;
  final int successfulFiles;
  final int failedFiles;
  final int totalBytes;
  final int uploadedBytes;
  final String status;
  
  BatchUploadProgress({
    required this.totalFiles,
    required this.completedFiles,
    required this.successfulFiles,
    required this.failedFiles,
    this.totalBytes = 0,
    this.uploadedBytes = 0,
    required this.status,
  });
  
  double get percentComplete => 
      totalFiles > 0 ? (completedFiles / totalFiles * 100) : 0;
      
  double get bytesPercentComplete =>
      totalBytes > 0 ? (uploadedBytes / totalBytes * 100) : 0;
}

/// Progress information for a single file upload
class FileUploadProgress {
  final String fileId;
  final String fileName;
  final String status;
  final int uploadedBytes;
  final int totalBytes;
  final int index;
  
  FileUploadProgress({
    required this.fileId,
    required this.fileName,
    required this.status,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.index,
  });
  
  double get percentComplete => 
      totalBytes > 0 ? (uploadedBytes / totalBytes * 100) : 0;
}

/// Result of a batch upload operation
class BatchUploadResult {
  final List<UploadFileItem> successful;
  final List<UploadFileItem> failed;
  final int totalCount;
  final int successCount;
  final int failureCount;
  
  BatchUploadResult({
    required this.successful,
    required this.failed,
    required this.totalCount,
    required this.successCount,
    required this.failureCount,
  });
  
  bool get isFullySuccessful => failureCount == 0 && successCount > 0;
  bool get isPartiallySuccessful => failureCount > 0 && successCount > 0;
  bool get isFullyFailed => successCount == 0 && failureCount > 0;
}

/// Status constants for batch uploads
class BatchUploadStatus {
  static const String notStarted = 'not_started';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String completedWithErrors = 'completed_with_errors';
  static const String failed = 'failed';
}

/// Status constants for file uploads
class FileUploadStatus {
  static const String waiting = 'waiting';
  static const String inProgress = 'inprogress';
  static const String success = 'success';
  static const String failed = 'failed';
}

/// Manages batch uploads with progress tracking
class BatchUploadManager {
  /// Callback for overall batch progress
  final Function(BatchUploadProgress progress)? onBatchProgressUpdate;
  
  /// Callback for individual file progress
  final Function(FileUploadProgress progress)? onFileProgressUpdate;
  
  /// Map to track individual file progress
  final Map<String, FileUploadProgress> _fileProgressMap = {};
  
  /// Constructor
  BatchUploadManager({
    this.onBatchProgressUpdate,
    this.onFileProgressUpdate,
  });
  
  /// Upload multiple files using the provided upload function
  Future<BatchUploadResult> uploadBatch<T>({
    required List<UploadFileItem> files,
    required Future<T> Function({
      required String parentFolderId,
      required String fileName,
      String? filePath,
      Uint8List? fileBytes,
      String? description,
      Function(UploadProgress)? onProgressUpdate,
    }) uploadFunction,
    required String parentFolderId,
    String? description,
    int maxConcurrent = 2, // Maximum number of concurrent uploads
  }) async {
    if (files.isEmpty) {
      return BatchUploadResult(
        successful: [],
        failed: [],
        totalCount: 0,
        successCount: 0,
        failureCount: 0,
      );
    }
    
    final totalCount = files.length;
    final successful = <UploadFileItem>[];
    final failed = <UploadFileItem>[];
    
    // Initialize progress tracking for each file
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final fileId = 'file-${i}-${DateTime.now().millisecondsSinceEpoch}';
      file.id = fileId;
      
      _fileProgressMap[fileId] = FileUploadProgress(
        fileId: fileId,
        fileName: file.name,
        status: FileUploadStatus.waiting,
        uploadedBytes: 0,
        totalBytes: file.bytes?.length ?? 0,
        index: i,
      );
    }
    
    // Define a local function to update batch progress
    void updateBatchProgress() {
      if (onBatchProgressUpdate != null) {
        // Calculate overall progress
        int totalBytes = 0;
        int uploadedBytes = 0;
        int completedFiles = 0;
        
        _fileProgressMap.values.forEach((fileProgress) {
          totalBytes += fileProgress.totalBytes;
          uploadedBytes += fileProgress.uploadedBytes;
          
          if (fileProgress.status == FileUploadStatus.success || 
              fileProgress.status == FileUploadStatus.failed) {
            completedFiles++;
          }
        });
        
        final progress = BatchUploadProgress(
          totalFiles: totalCount,
          completedFiles: completedFiles,
          successfulFiles: successful.length,
          failedFiles: failed.length,
          totalBytes: totalBytes,
          uploadedBytes: uploadedBytes,
          status: completedFiles < totalCount 
              ? BatchUploadStatus.inProgress 
              : (failed.isEmpty ? BatchUploadStatus.completed : BatchUploadStatus.completedWithErrors),
        );
        
        onBatchProgressUpdate!(progress);
      }
    }
    
    // Initial progress update
    updateBatchProgress();
    
    // Process files in batches to limit concurrency
    for (int i = 0; i < files.length; i += maxConcurrent) {
      final end = (i + maxConcurrent < files.length) ? i + maxConcurrent : files.length;
      final batch = files.sublist(i, end);
      
      // Process this batch concurrently
      final futures = batch.map((file) async {
        try {
          EVLogger.debug('Starting upload for file', {
            'fileName': file.name,
            'fileId': file.id,
            'index': files.indexOf(file) + 1,
            'totalFiles': files.length,
          });
          
          // Update file status to in progress
          _updateFileProgress(file.id!, FileUploadStatus.inProgress);
          
          // Call the provided upload function with progress tracking
          final result = await uploadFunction(
            parentFolderId: parentFolderId,
            fileName: file.name,
            filePath: file.path,
            fileBytes: file.bytes,
            description: description,
            onProgressUpdate: (uploadProgress) {
              // Map the upload service progress to our file progress
              _handleUploadProgress(file.id!, uploadProgress, updateBatchProgress);
            },
          );
          
          // Mark as successful
          successful.add(file);
          _updateFileProgress(file.id!, FileUploadStatus.success);
          
          EVLogger.debug('Upload successful', {
            'fileName': file.name,
            'result': result,
          });
          
          return true;
        } catch (e) {
          // Mark as failed with error details
          final fileWithError = file.copyWithError(e.toString());
          failed.add(fileWithError);
          _updateFileProgress(file.id!, FileUploadStatus.failed);
          
          EVLogger.error('Upload failed', {
            'fileName': file.name,
            'error': e.toString(),
          });
          
          return false;
        } finally {
          // Update batch progress
          updateBatchProgress();
        }
      }).toList();
      
      // Wait for all uploads in this batch to complete
      await Future.wait(futures);
    }
    
    // Final progress update
    updateBatchProgress();
    
    // Return results
    return BatchUploadResult(
      successful: successful,
      failed: failed,
      totalCount: totalCount,
      successCount: successful.length,
      failureCount: failed.length,
    );
  }
  
  /// Handle progress updates from the upload service
  void _handleUploadProgress(String fileId, UploadProgress uploadProgress, Function updateBatchProgress) {
    if (_fileProgressMap.containsKey(fileId)) {
      final fileProgress = _fileProgressMap[fileId]!;
      
      // Update file progress
      _fileProgressMap[fileId] = FileUploadProgress(
        fileId: fileId,
        fileName: fileProgress.fileName,
        status: uploadProgress.status,
        uploadedBytes: uploadProgress.uploadedBytes,
        totalBytes: uploadProgress.totalBytes,
        index: fileProgress.index,
      );
      
      // Notify listeners
      onFileProgressUpdate?.call(_fileProgressMap[fileId]!);
      
      // Update batch progress
      updateBatchProgress();
    }
  }
  
  /// Update progress for a specific file
  void _updateFileProgress(String fileId, String status) {
    if (_fileProgressMap.containsKey(fileId)) {
      final fileProgress = _fileProgressMap[fileId]!;
      
      // Update file status
      _fileProgressMap[fileId] = FileUploadProgress(
        fileId: fileId,
        fileName: fileProgress.fileName,
        status: status,
        uploadedBytes: status == FileUploadStatus.success ? fileProgress.totalBytes : fileProgress.uploadedBytes,
        totalBytes: fileProgress.totalBytes,
        index: fileProgress.index,
      );
      
      // Notify listeners
      onFileProgressUpdate?.call(_fileProgressMap[fileId]!);
    }
  }
}