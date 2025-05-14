import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Service for managing local file storage for offline access
/// 
/// This service handles storing, retrieving, and deleting
/// file content in app-specific storage.
class OfflineFileService {
  /// Base directory for offline files
  Future<Directory> get _baseDir async {
    // Get app-specific directory
    final appDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${appDir.path}/offline_files');
    
    // Create the directory if it doesn't exist
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    
    return offlineDir;
  }
  
  /// Store file content to app-specific storage
  /// 
  /// Returns the local file path where the content was stored
  Future<String> storeFile(String fileId, dynamic content) async {
    try {
      // Get base directory for offline files
      final dir = await _baseDir;
      
      // Create a safe file name using the fileId
      final safeName = fileId.replaceAll(RegExp(r'[^\w]'), '_');
      final filePath = path.join(dir.path, safeName);
      
      // Create and write to file
      final file = File(filePath);
      
      // Handle different content types
      if (content is Uint8List) {
        await file.writeAsBytes(content);
      } else if (content is String) {
        // If it's a file path, copy the file
        if (await File(content).exists()) {
          await File(content).copy(filePath);
        } else {
          // If it's raw string content, convert to bytes
          await file.writeAsBytes(Uint8List.fromList(content.codeUnits));
        }
      } else {
        throw Exception('Unsupported content type: ${content.runtimeType}');
      }
      
      return filePath;
    } catch (e) {
      EVLogger.error('Failed to store file for offline access', {
        'fileId': fileId,
        'error': e.toString(),
      });
      rethrow;
    }
  }
  
  /// Retrieve file content from app-specific storage
  /// 
  /// Returns the file content as bytes, or null if not found
  Future<Uint8List?> getFileContent(String filePath) async {
    try {
      final file = File(filePath);
      
      if (await file.exists()) {
        return await file.readAsBytes();
      } else {
        EVLogger.warning('Offline file not found', {
          'path': filePath,
        });
        return null;
      }
    } catch (e) {
      EVLogger.error('Failed to read offline file', {
        'path': filePath,
        'error': e.toString(),
      });
      return null;
    }
  }
  
  /// Delete a file from app-specific storage
  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      EVLogger.error('Failed to delete offline file', {
        'path': filePath,
        'error': e.toString(),
      });
      rethrow;
    }
  }
  
  /// Calculate total storage used by offline files
  Future<int> calculateTotalStorageUsed() async {
    try {
      final dir = await _baseDir;
      int totalSize = 0;
      
      await for (final file in dir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      EVLogger.error('Failed to calculate storage usage', {
        'error': e.toString(),
      });
      return 0;
    }
  }
}
