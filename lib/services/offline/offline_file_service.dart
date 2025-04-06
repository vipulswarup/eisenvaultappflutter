import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Service for managing local file storage for offline access
/// 
/// This service handles storing, retrieving, and deleting
/// file content on the device's local storage.
class OfflineFileService {
  /// Base directory for offline files
  Future<Directory> get _baseDir async {
    // Get appropriate directory based on platform
    final appDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${appDir.path}/offline_files');
    
    // Create the directory if it doesn't exist
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    
    return offlineDir;
  }
  
  /// Store file content to local storage
  /// 
  /// Returns the local file path where the content was stored
  Future<String> storeFile(String fileId, Uint8List content) async {
    try {
      // Get base directory for offline files
      final dir = await _baseDir;
      
      // Create a safe file name using the fileId
      // We use the fileId as it's guaranteed to be unique
      final safeName = fileId.replaceAll(RegExp(r'[^\w]'), '_');
      final filePath = path.join(dir.path, safeName);
      
      // Create and write to file
      final file = File(filePath);
      await file.writeAsBytes(content);
      
      EVLogger.debug('File saved for offline access', {
        'fileId': fileId,
        'path': filePath,
        'size': content.length,
      });
      
      return filePath;
    } catch (e) {
      EVLogger.error('Failed to store file for offline access', {
        'fileId': fileId,
        'error': e.toString(),
      });
      rethrow;
    }
  }
  
  /// Retrieve file content from local storage
  /// 
  /// Returns the file content as bytes, or null if not found
  Future<Uint8List?> getFileContent(String filePath) async {
    try {
      final file = File(filePath);
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        EVLogger.debug('Retrieved offline file content', {
          'path': filePath,
          'size': bytes.length,
        });
        
        return bytes;
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
  
  /// Delete a file from local storage
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
        
        EVLogger.debug('Deleted offline file', {
          'path': filePath,
        });
        
        return true;
      } else {
        EVLogger.warning('Could not delete offline file: file not found', {
          'path': filePath,
        });
        return false;
      }
    } catch (e) {
      EVLogger.error('Failed to delete offline file', {
        'path': filePath,
        'error': e.toString(),
      });
      return false;
    }
  }
  
  /// Check if file exists in local storage
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      EVLogger.error('Error checking if file exists', {
        'path': filePath,
        'error': e.toString(),
      });
      return false;
    }
  }
  
  /// Calculate total size of all offline files
  Future<int> calculateTotalStorageUsed() async {
    try {
      final dir = await _baseDir;
      int totalSize = 0;
      
      // List all files in the offline directory
      final entities = await dir.list().toList();
      
      // Get the size of each file
      for (var entity in entities) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      EVLogger.debug('Total offline storage used', {
        'bytes': totalSize,
        'megabytes': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      });
      
      return totalSize;
    } catch (e) {
      EVLogger.error('Failed to calculate offline storage usage', e);
      return 0;
    }
  }
  
  /// Clear all offline files
  Future<void> clearAllFiles() async {
    try {
      final dir = await _baseDir;
      
      if (await dir.exists()) {
        // Delete and recreate the directory to clear all files
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
        
        EVLogger.info('All offline files cleared');
      }
    } catch (e) {
      EVLogger.error('Failed to clear offline files', e);
      rethrow;
    }
  }
}
