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

/// Status constants for file uploads
class UploadStatus {
  static const String waiting = 'waiting';
  static const String inProgress = 'inprogress';
  static const String success = 'success';
  static const String failed = 'failed';
}
