/// Exception thrown when an offline operation fails
class OfflineException implements Exception {
  /// The error message
  final String message;

  /// Constructor
  OfflineException(this.message);

  @override
  String toString() => 'OfflineException: $message';
} 