import 'dart:typed_data';

/// Represents a file to be uploaded
///
/// This class encapsulates all information needed to upload a file,
/// including either the file path (native platforms) or bytes (web).
class UploadFileItem {
  /// Name of the file
  final String name;
  
  /// File path for native platforms (mutually exclusive with bytes)
  final String? path;
  
  /// File bytes for web platform (mutually exclusive with path)
  final Uint8List? bytes;
  
  /// ID assigned for tracking this upload
  String? id;
  
  /// Error message if the upload failed
  String? errorMessage;
  
  /// Constructor requires a name and either path or bytes
  UploadFileItem({
    required this.name,
    this.path,
    this.bytes,
    this.id,
    this.errorMessage,
  });
  
  /// Create a copy of this item with an error message
  ///
  /// This is useful when an upload fails and we need to
  /// preserve the original item but add error information.
  UploadFileItem copyWithError(String error) {
    return UploadFileItem(
      name: name,
      path: path,
      bytes: bytes,
      id: id,
      errorMessage: error,
    );
  }
  
  /// Determines if this file has bytes (web upload)
  bool get hasBytes => bytes != null;
  
  /// Determines if this file has a path (native upload)
  bool get hasPath => path != null;
  
  /// Determines if this file has encountered an error
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

/// Progress information for a batch upload
///
/// This class provides a comprehensive view of a batch upload operation,
/// including counts of successful/failed files and overall progress.
class BatchUploadProgress {
  /// Total number of files in the batch
  final int totalFiles;
  
  /// Number of files that have completed (success or failure)
  final int completedFiles;
  
  /// Number of files that completed successfully
  final int successfulFiles;
  
  /// Number of files that failed
  final int failedFiles;
  
  /// Total bytes across all files
  final int totalBytes;
  
  /// Total bytes uploaded so far
  final int uploadedBytes;
  
  /// Current status of the batch operation
  final String status;
  
  /// Constructor requires counts and status
  BatchUploadProgress({
    required this.totalFiles,
    required this.completedFiles,
    required this.successfulFiles,
    required this.failedFiles,
    this.totalBytes = 0,
    this.uploadedBytes = 0,
    required this.status,
  });
  
  /// Calculate the percentage complete based on file count
  double get percentComplete => 
      totalFiles > 0 ? (completedFiles / totalFiles * 100) : 0;
      
  /// Calculate the percentage complete based on bytes
  double get bytesPercentComplete =>
      totalBytes > 0 ? (uploadedBytes / totalBytes * 100) : 0;
      
  /// Determines if the batch is fully complete
  bool get isComplete => 
      completedFiles == totalFiles && totalFiles > 0;
      
  /// Determines if the batch completed with partial success
  bool get hasPartialSuccess =>
      successfulFiles > 0 && failedFiles > 0;
      
  /// Determines if all files in the batch succeeded
  bool get isFullySuccessful =>
      successfulFiles == totalFiles && totalFiles > 0;
      
  /// Creates a copy with updated values
  BatchUploadProgress copyWith({
    int? totalFiles,
    int? completedFiles,
    int? successfulFiles,
    int? failedFiles,
    int? totalBytes,
    int? uploadedBytes,
    String? status,
  }) {
    return BatchUploadProgress(
      totalFiles: totalFiles ?? this.totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
      successfulFiles: successfulFiles ?? this.successfulFiles,
      failedFiles: failedFiles ?? this.failedFiles,
      totalBytes: totalBytes ?? this.totalBytes,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      status: status ?? this.status,
    );
  }
}

/// Progress information for a single file upload in a batch
///
/// This provides detailed tracking of an individual file's upload progress
/// within a larger batch operation.
class FileUploadProgress {
  /// ID of the file being uploaded
  final String fileId;
  
  /// Name of the file
  final String fileName;
  
  /// Current status of the upload
  final String status;
  
  /// Number of bytes uploaded so far
  final int uploadedBytes;
  
  /// Total size of the file in bytes
  final int totalBytes;
  
  /// Index of this file in the batch
  final int index;
  
  /// Constructor requires all fields
  FileUploadProgress({
    required this.fileId,
    required this.fileName,
    required this.status,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.index,
  });
  
  /// Calculate percentage complete
  double get percentComplete => 
      totalBytes > 0 ? (uploadedBytes / totalBytes * 100) : 0;
      
  /// Determine if the upload is complete
  bool get isComplete => 
      status == FileUploadStatus.success || status == FileUploadStatus.failed;
      
  /// Determine if the upload is in progress
  bool get isInProgress => status == FileUploadStatus.inProgress;
      
  /// Create a copy with updated values
  FileUploadProgress copyWith({
    String? fileId,
    String? fileName,
    String? status,
    int? uploadedBytes,
    int? totalBytes,
    int? index,
  }) {
    return FileUploadProgress(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      index: index ?? this.index,
    );
  }
}

/// Result of a batch upload operation
///
/// This provides a summary of the batch upload after completion,
/// including lists of successful and failed files.
class BatchUploadResult {
  /// List of files that uploaded successfully
  final List<UploadFileItem> successful;
  
  /// List of files that failed to upload
  final List<UploadFileItem> failed;
  
  /// Total number of files in the batch
  final int totalCount;
  
  /// Number of successful uploads
  final int successCount;
  
  /// Number of failed uploads
  final int failureCount;
  
  /// Constructor requires all fields
  BatchUploadResult({
    required this.successful,
    required this.failed,
    required this.totalCount,
    required this.successCount,
    required this.failureCount,
  });
  
  /// Determines if all files were uploaded successfully
  bool get isFullySuccessful => failureCount == 0 && successCount > 0;
  
  /// Determines if some files failed but some succeeded
  bool get isPartiallySuccessful => failureCount > 0 && successCount > 0;
  
  /// Determines if all files failed
  bool get isFullyFailed => successCount == 0 && failureCount > 0;
}

/// Status constants for batch uploads
class BatchUploadStatus {
  /// Upload has not yet started
  static const String notStarted = 'not_started';
  
  /// Upload is currently in progress
  static const String inProgress = 'in_progress';
  
  /// Upload has completed successfully
  static const String completed = 'completed';
  
  /// Upload has completed with some errors
  static const String completedWithErrors = 'completed_with_errors';
  
  /// Upload has failed completely
  static const String failed = 'failed';
}

/// Status constants for file uploads
class FileUploadStatus {
  /// File is waiting to be uploaded
  static const String waiting = 'waiting';
  
  /// File is currently being uploaded
  static const String inProgress = 'inprogress';
  
  /// File was uploaded successfully
  static const String success = 'success';
  
  /// File upload failed
  static const String failed = 'failed';
}


/// Status constants for file uploads
class UploadStatus {
  static const String waiting = 'waiting';
  static const String inProgress = 'inprogress';
  static const String success = 'success';
  static const String failed = 'failed';
}

/// Represents the progress of an upload operation
class UploadProgress {
  /// Unique identifier for the file being uploaded
  final String fileId;
  
  /// Number of bytes uploaded so far
  final int uploadedBytes;
  
  /// Total size of the file in bytes
  final int totalBytes;
  
  /// Current status of the upload
  final String status;
  
  /// Constructor
  UploadProgress({
    required this.fileId,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.status,
  });
  
  /// Calculate percentage complete
  double get percentComplete => 
      totalBytes > 0 ? (uploadedBytes / totalBytes * 100) : 0;
}