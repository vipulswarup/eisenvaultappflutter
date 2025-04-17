/// Model class for tracking file upload progress
class UploadProgress {
  final String id;
  final String fileName;
  final double progress;
  final bool isComplete;
  final String? error;

  const UploadProgress({
    required this.id,
    required this.fileName,
    required this.progress,
    this.isComplete = false,
    this.error,
  });

  UploadProgress copyWith({
    String? id,
    String? fileName,
    double? progress,
    bool? isComplete,
    String? error,
  }) {
    return UploadProgress(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      isComplete: isComplete ?? this.isComplete,
      error: error ?? this.error,
    );
  }
} 