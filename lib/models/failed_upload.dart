/// Model class for tracking failed file uploads
class FailedUpload {
  final String id;
  final String fileName;
  final String? error;
  final DateTime failedAt;
  final Map<String, dynamic>? metadata;

  const FailedUpload({
    required this.id,
    required this.fileName,
    this.error,
    required this.failedAt,
    this.metadata,
  });

  FailedUpload copyWith({
    String? id,
    String? fileName,
    String? error,
    DateTime? failedAt,
    Map<String, dynamic>? metadata,
  }) {
    return FailedUpload(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      error: error ?? this.error,
      failedAt: failedAt ?? this.failedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'error': error,
      'failedAt': failedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory FailedUpload.fromJson(Map<String, dynamic> json) {
    return FailedUpload(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      error: json['error'] as String?,
      failedAt: DateTime.parse(json['failedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
} 