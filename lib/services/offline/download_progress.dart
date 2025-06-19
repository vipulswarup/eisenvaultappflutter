class DownloadProgress {
  final String fileName;
  final double progress;
  final int totalFiles;
  final int currentFileIndex;

  const DownloadProgress({
    required this.fileName,
    required this.progress,
    required this.totalFiles,
    required this.currentFileIndex,
  });

  /// Calculate overall progress based on completed files for folder downloads
  double get overallProgress {
    if (totalFiles <= 1) {
      // For single files, use the individual file progress
      return progress;
    } else {
      // For folders, calculate progress based on completed files
      // currentFileIndex represents the file being processed (1-based)
      // We want to show progress based on completed files (0-based)
      final completedFiles = (currentFileIndex - 1).clamp(0, totalFiles);
      return totalFiles > 0 ? completedFiles / totalFiles : 0.0;
    }
  }

  /// Get a user-friendly progress description
  String get progressDescription {
    if (totalFiles <= 1) {
      return 'Downloading file';
    } else {
      final completedFiles = (currentFileIndex - 1).clamp(0, totalFiles);
      return 'Downloaded $completedFiles of $totalFiles files';
    }
  }

  DownloadProgress copyWith({
    String? fileName,
    double? progress,
    int? totalFiles,
    int? currentFileIndex,
  }) {
    return DownloadProgress(
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      totalFiles: totalFiles ?? this.totalFiles,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
    );
  }
} 