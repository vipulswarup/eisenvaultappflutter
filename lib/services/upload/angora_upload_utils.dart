import 'dart:typed_data';
import 'package:eisenvaultappflutter/services/upload/upload_constants.dart';

/// Utility functions for Angora uploads
class AngoraUploadUtils {
  /// Generate a unique file ID in Angora format
  /// Format: parentId_fileName_fileSize_timestamp
  static String generateFileId(String parentId, String fileName, int fileSize) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${parentId}_${fileName}_${fileSize}_$timestamp';
  }
  
  /// Determine appropriate chunk size based on file size
  /// Logic adapted from Angora's useUpload.jsx
  static int getChunkSize(int fileSizeInBytes) {
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
  static List<UploadChunk> splitIntoChunks({
    required String fileId,
    required String fileName,
    required Uint8List fileBytes,
  }) {
    final chunkSize = getChunkSize(fileBytes.length);
    final totalChunks = (fileBytes.length / chunkSize).ceil();
    

    final chunks = <UploadChunk>[];
    
    for (int i = 0; i < totalChunks; i++) {
      final startByte = i * chunkSize;
      final endByte = (startByte + chunkSize) > fileBytes.length 
          ? fileBytes.length 
          : startByte + chunkSize;
      
      final chunkData = fileBytes.sublist(startByte, endByte);
      
      chunks.add(UploadChunk(
        fileId: fileId,
        fileName: fileName,
        data: chunkData,
        startByte: startByte,
        totalFileSize: fileBytes.length,
      ));
    }
    
    return chunks;
  }
}