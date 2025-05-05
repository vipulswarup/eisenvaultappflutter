import 'package:open_file/open_file.dart' as open_file;

/// Utility class for opening files
class OpenFile {
  /// Opens a file at the given path using the system's default application
  static Future<open_file.OpenResult> open(String filePath) async {
    return await open_file.OpenFile.open(filePath);
  }
}

/// Result type for file opening operations
enum ResultType {
  done,
  error,
  noAppToOpen,
  fileNotFound,
  permissionDenied,
} 