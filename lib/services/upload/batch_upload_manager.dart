import 'dart:async';
import 'dart:typed_data';
import 'package:eisenvaultappflutter/models/upload/batch_upload_models.dart';
import 'package:eisenvaultappflutter/models/upload/upload_progress.dart';
import 'package:eisenvaultappflutter/services/upload/base/upload_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Manages batch uploads with progress tracking
///
/// This class coordinates uploading multiple files as a batch,
/// handling concurrency, progress tracking, and error management.
class BatchUploadManager {
  /// Callback for overall batch progress
  Function(BatchUploadProgress progress)? onBatchProgressUpdate;
  
  /// Callback for individual file progress
  Function(FileUploadProgress progress)? onFileProgressUpdate;
  
  /// Map to track individual file progress
  final Map<String, FileUploadProgress> _fileProgressMap = {};
  
  /// Default maximum concurrent uploads
  static const int defaultMaxConcurrent = 2;
  
  /// Constructor with optional callbacks
  BatchUploadManager({
    this.onBatchProgressUpdate,
    this.onFileProgressUpdate,
  });
  
  /// Upload multiple files using the provided upload service
  ///
  /// Parameters:
  /// - [files]: List of files to upload
  /// - [uploadService]: The upload service to use (Angora, Alfresco, etc.)
  /// - [parentFolderId]: ID of the folder where files will be uploaded
  /// - [description]: Optional description for all files
  /// - [maxConcurrent]: Maximum number of concurrent uploads (default: 2)
  ///
  /// Returns a BatchUploadResult with lists of successful and failed files
  Future<BatchUploadResult> uploadBatch({
    required List<UploadFileItem> files,
    required BaseUploadService uploadService,
    required String parentFolderId,
    String? description,
    int maxConcurrent = defaultMaxConcurrent,
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
    _initializeFileProgress(files);
    
    // Initial progress update
    _updateBatchProgress(successful, failed, totalCount);
    
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
          
          // Call the upload service with progress tracking
          final result = await uploadService.uploadDocument(
            parentFolderId: parentFolderId,
            fileName: file.name,
            filePath: file.path,
            fileBytes: file.bytes,
            description: description,
            onProgressUpdate: (uploadProgress) {
              // Map the upload service progress to our file progress
              _handleUploadProgress(file.id!, uploadProgress);
              // Update batch progress
              _updateBatchProgress(successful, failed, totalCount);
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
          _updateBatchProgress(successful, failed, totalCount);
        }
      }).toList();
      
      // Wait for all uploads in this batch to complete
      await Future.wait(futures);
    }
    
    // Final progress update
    _updateBatchProgress(successful, failed, totalCount);
    
    // Return results
    return BatchUploadResult(
      successful: successful,
      failed: failed,
      totalCount: totalCount,
      successCount: successful.length,
      failureCount: failed.length,
    );
  }
  
  /// Initialize progress tracking for all files
  void _initializeFileProgress(List<UploadFileItem> files) {
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
  }
  
  /// Handle progress updates from the upload service
  void _handleUploadProgress(String fileId, UploadProgress uploadProgress) {
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
  
  /// Update overall batch progress and notify listeners
  void _updateBatchProgress(List<UploadFileItem> successful, List<UploadFileItem> failed, int totalCount) {
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
      
      // Determine batch status
      final String status;
      if (completedFiles < totalCount) {
        status = BatchUploadStatus.inProgress;
      } else if (failed.isEmpty) {
        status = BatchUploadStatus.completed;
      } else {
        status = BatchUploadStatus.completedWithErrors;
      }
      
      // Create progress object
      final progress = BatchUploadProgress(
        totalFiles: totalCount,
        completedFiles: completedFiles,
        successfulFiles: successful.length,
        failedFiles: failed.length,
        totalBytes: totalBytes,
        uploadedBytes: uploadedBytes,
        status: status,
      );
      
      // Notify listeners
      onBatchProgressUpdate!(progress);
    }
  }
  
  /// Get the current progress for a specific file
  FileUploadProgress? getFileProgress(String fileId) {
    return _fileProgressMap[fileId];
  }
  
  /// Get all file progress objects
  List<FileUploadProgress> getAllFileProgress() {
    return _fileProgressMap.values.toList();
  }
  
  /// Clear progress tracking data
  void clearProgress() {
    _fileProgressMap.clear();
  }
}