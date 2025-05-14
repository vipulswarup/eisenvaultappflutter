import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:eisenvaultappflutter/services/offline/offline_core.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Implementation of [OfflineStorageProvider] that stores files in app-specific storage
class LocalStorageProvider implements OfflineStorageProvider {
  static const String _offlineDir = 'offline_files';
  late final Directory _baseDir;
  bool _initialized = false;
  
  /// Initialize the storage provider
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      // Get app-specific directory
      final appDir = await getApplicationDocumentsDirectory();
      _baseDir = Directory(path.join(appDir.path, _offlineDir));
      
      if (!await _baseDir.exists()) {
        await _baseDir.create(recursive: true);
      }
      
      _initialized = true;
    } catch (e) {
      EVLogger.error('Failed to initialize storage provider', {'error': e});
      rethrow;
    }
  }
  
  String _getFilePath(String itemId) {
    return path.join(_baseDir.path, itemId);
  }
  
  @override
  Future<String> storeFile(String itemId, Uint8List content) async {
    await init();
    
    try {
      final file = File(_getFilePath(itemId));
      await file.writeAsBytes(content);
      
      return file.path;
    } catch (e) {
      EVLogger.error('Failed to store file', {'itemId': itemId, 'error': e});
      rethrow;
    }
  }
  
  @override
  Future<Uint8List?> getFile(String itemId) async {
    await init();
    
    try {
      final file = File(_getFilePath(itemId));
      if (!await file.exists()) {
        EVLogger.warning('File not found', {'itemId': itemId});
        return null;
      }
      return await file.readAsBytes();
    } catch (e) {
      EVLogger.error('Failed to read file', {'itemId': itemId, 'error': e});
      return null;
    }
  }
  
  @override
  Future<void> deleteFile(String itemId) async {
    await init();
    
    try {
      final file = File(_getFilePath(itemId));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      EVLogger.error('Failed to delete file', {'itemId': itemId, 'error': e});
      rethrow;
    }
  }
  
  @override
  Future<int> getStorageUsed() async {
    await init();
    
    try {
      int totalSize = 0;
      await for (final file in _baseDir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (e) {
      EVLogger.error('Failed to calculate storage used', {'error': e});
      return 0;
    }
  }
  
  @override
  Future<void> clearStorage() async {
    await init();
    
    try {
      if (await _baseDir.exists()) {
        await _baseDir.delete(recursive: true);
        await _baseDir.create(recursive: true);
      }
    } catch (e) {
      EVLogger.error('Failed to clear storage', {'error': e});
      rethrow;
    }
  }
} 