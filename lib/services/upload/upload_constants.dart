import 'dart:typed_data';


/// Constants related to file uploads across the application
class UploadConstants {
  /// Maximum number of retry attempts for chunk uploads
  static const int maxRetries = 3;
  
  /// Base delay in milliseconds between retries (increases with retry count)
  static const int retryDelayMs = 2000;
  
  /// Default timeout for upload operations in seconds
  static const int uploadTimeoutSeconds = 30;
  
  /// Default maximum concurrent uploads
  static const int maxConcurrentUploads = 2;
}

/// Possible states of a file upload
class UploadStatus {
  static const String waiting = 'waiting';
  static const String inProgress = 'inprogress';
  static const String success = 'success';
  static const String failed = 'failed';
}

/// Represents a chunk of a file being uploaded
class UploadChunk {
  final String fileId;
  final String fileName;
  final Uint8List data;
  final int startByte;
  final int totalFileSize;
  
  UploadChunk({
    required this.fileId,
    required this.fileName,
    required this.data,
    required this.startByte,
    required this.totalFileSize,
  });
}

/// Progress information for a file upload
class UploadProgress {
  final String fileId;
  final int uploadedBytes;
  final int totalBytes;
  final String status;
  
  UploadProgress({
    required this.fileId,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.status,
  });
  
  double get percentComplete => 
      totalBytes > 0 ? (uploadedBytes / totalBytes * 100) : 0;
}
