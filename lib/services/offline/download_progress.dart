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