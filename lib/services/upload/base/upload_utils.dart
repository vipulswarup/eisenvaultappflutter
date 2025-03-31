import 'dart:typed_data';

/// Utility functions for file uploads across different backends
///
/// This class provides common utility methods needed by various
/// upload service implementations, centralizing functionality
/// to avoid code duplication.
class UploadUtils {
  /// Generate a unique file ID in a standardized format
  /// 
  /// Format: parentId_fileName_fileSize_timestamp
  /// This format ensures uniqueness and contains metadata
  /// about the file being uploaded, useful for debugging.
  static String generateFileId(String parentId, String fileName, int fileSize) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${parentId}_${fileName}_${fileSize}_$timestamp';
  }
  
  /// Determine appropriate chunk size based on file size
  /// 
  /// For very small files, no chunking is needed. For larger files,
  /// this calculates an appropriate chunk size to balance:
  /// - Number of HTTP requests
  /// - Memory usage
  /// - Upload reliability
  /// 
  /// Returns the recommended chunk size in bytes
  static int calculateChunkSize(int fileSizeInBytes) {
    const bytesToMb = 1000000;
    
    // Default to full file size for very small files
    if (fileSizeInBytes <= bytesToMb / 2) {
      return fileSizeInBytes;
    }
    
    // For larger files, divide into progressively more chunks
    if (fileSizeInBytes <= bytesToMb * 1) {
      return fileSizeInBytes; // 1 chunk
    } else if (fileSizeInBytes <= bytesToMb * 5) {
      return fileSizeInBytes ~/ 2; // 2 chunks
    } else if (fileSizeInBytes <= bytesToMb * 10) {
      return fileSizeInBytes ~/ 3; // 3 chunks
    } else if (fileSizeInBytes <= bytesToMb * 20) {
      return fileSizeInBytes ~/ 4; // 4 chunks
    } else if (fileSizeInBytes <= bytesToMb * 40) {
      return fileSizeInBytes ~/ 6; // 6 chunks
    } else if (fileSizeInBytes <= bytesToMb * 60) {
      return fileSizeInBytes ~/ 8; // 8 chunks
    } else if (fileSizeInBytes <= bytesToMb * 80) {
      return fileSizeInBytes ~/ 10; // 10 chunks
    } else if (fileSizeInBytes <= bytesToMb * 100) {
      return fileSizeInBytes ~/ 12; // 12 chunks
    } else {
      // For very large files (>100MB), use ~10MB chunks
      return 10 * bytesToMb;
    }
  }
  
  /// Split a file into chunks for uploading
  /// 
  /// This is particularly useful for:
  /// - Large file uploads
  /// - Resumable uploads
  /// - Better error recovery
  /// 
  /// Returns a list of file chunks with appropriate metadata
  static List<FileChunk> splitIntoChunks({
    required String fileId,
    required String fileName,
    required Uint8List fileBytes,
  }) {
    final chunkSize = calculateChunkSize(fileBytes.length);
    final totalChunks = (fileBytes.length / chunkSize).ceil();
  
    
    final chunks = <FileChunk>[];
    
    for (int i = 0; i < totalChunks; i++) {
      final startByte = i * chunkSize;
      final endByte = (startByte + chunkSize) > fileBytes.length 
          ? fileBytes.length 
          : startByte + chunkSize;
      
      final chunkData = fileBytes.sublist(startByte, endByte);
      
      chunks.add(FileChunk(
        fileId: fileId,
        fileName: fileName,
        data: chunkData,
        startByte: startByte,
        totalFileSize: fileBytes.length,
      ));
    }
    
    return chunks;
  }
  
  /// Create a filename that's compatible with the repository
  /// 
  /// Replaces problematic characters and enforces length limits
  static String sanitizeFileName(String fileName) {
    // Remove characters not allowed in filenames on most systems
    var sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    
    // Trim spaces from beginning and end
    sanitized = sanitized.trim();
    
    // Limit to 255 characters (common filesystem limit)
    if (sanitized.length > 255) {
      // Keep extension if present
      final lastDotIndex = sanitized.lastIndexOf('.');
      if (lastDotIndex != -1 && lastDotIndex > sanitized.length - 6) {
        final extension = sanitized.substring(lastDotIndex);
        sanitized = sanitized.substring(0, 255 - extension.length) + extension;
      } else {
        sanitized = sanitized.substring(0, 255);
      }
    }
    
    // If name is empty after sanitization, provide a default
    if (sanitized.isEmpty) {
      sanitized = 'unnamed_file';
    }
    
    return sanitized;
  }
}

/// Represents a chunk of a file being uploaded
///
/// This class encapsulates all metadata needed for a chunked upload,
/// including the binary data and positioning information.
class FileChunk {
  /// ID of the file this chunk belongs to
  final String fileId;
  
  /// Name of the file
  final String fileName;
  
  /// The actual binary data for this chunk
  final Uint8List data;
  
  /// Starting byte position in the original file
  final int startByte;
  
  /// Size of the complete file in bytes
  final int totalFileSize;
  
  /// Constructor requires all fields to properly identify the chunk
  FileChunk({
    required this.fileId,
    required this.fileName,
    required this.data,
    required this.startByte,
    required this.totalFileSize,
  });
  
  /// Calculate the end byte position of this chunk
  int get endByte => startByte + data.length;
  
  /// Calculate the chunk's size in bytes
  int get size => data.length;
  
  /// Determine if this is the last chunk in the file
  bool get isLastChunk => endByte >= totalFileSize;
}
