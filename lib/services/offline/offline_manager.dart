import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_file_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Central manager for offline content functionality
///
/// This service coordinates between database, file storage, and
/// network operations to provide a seamless offline experience.
class OfflineManager {
  // Services for database and file operations
  final OfflineDatabaseService _database = OfflineDatabaseService.instance;
  final OfflineFileService _fileService = OfflineFileService();
  
  // Connectivity for checking network status
  final Connectivity _connectivity = Connectivity();
  
  /// Check if the device is currently offline
  Future<bool> isOffline() async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.none;
  }
  
  /// Keep an item available for offline access
  ///
  /// If the item is a folder, optionally include all its contents recursively
  Future<bool> keepOffline({
    required BrowseItem item,
    required String instanceType,
    required String baseUrl,
    required String authToken,
    String? parentId,
    bool recursive = false,
  }) async {
    try {
      EVLogger.info('Keeping item offline', {
        'itemId': item.id, 
        'itemName': item.name,
        'type': item.type,
        'recursive': recursive,
      });
      
      // Insert the item into the database without file path yet
      await _database.insertItem(item, parentId: parentId);
      
      // If it's a document, download and store its content
      if (item.type != 'folder' && !item.isDepartment) {
        EVLogger.debug('Downloading document content for offline access');
        
        // Get the document content from the server
        final documentService = DocumentServiceFactory.getService(
          instanceType,
          baseUrl,
          authToken,
        );
        
        // Download the document content
        final content = await documentService.getDocumentContent(item);
        
        // Store the content and get the file path
        final filePath = await _fileService.storeFile(item.id, content);
        
        // Update the database with the file path
        await _database.updateItemFilePath(item.id, filePath);
      }
      
      // If this is a folder and recursive is true, download all children
      if (recursive && (item.type == 'folder' || item.isDepartment)) {
        EVLogger.debug('Recursively downloading folder contents', {
          'folderId': item.id,
          'folderName': item.name,
        });
        
        // Get the browse service for this repository type
        final browseService = BrowseServiceFactory.getService(
          instanceType,
          baseUrl,
          authToken,
        );
        
        // Get all children of this folder
        final children = await browseService.getChildren(item);
        
        // Recursively keep each child offline
        for (var child in children) {
          await keepOffline(
            item: child,
            instanceType: instanceType,
            baseUrl: baseUrl,
            authToken: authToken,
            parentId: item.id,
            recursive: true,
          );
        }
      }
      
      return true;
    } catch (e) {
      EVLogger.error('Failed to keep item offline', {
        'itemId': item.id,
        'itemName': item.name,
        'error': e.toString(),
      });
      return false;
    }
  }
  
  /// Check if an item is available offline
  Future<bool> isAvailableOffline(String itemId) async {
    try {
      final item = await _database.getItem(itemId);
      return item != null;
    } catch (e) {
      EVLogger.error('Error checking if item is available offline', {
        'itemId': itemId,
        'error': e.toString(),
      });
      return false;
    }
  }
  
  /// Get offline file content for a document
  Future<Uint8List?> getFileContent(String itemId) async {
    try {
      // Get the item metadata from database
      final item = await _database.getItem(itemId);
      
      if (item == null) {
        EVLogger.warning('Item not found in offline database', {
          'itemId': itemId,
        });
        return null;
      }
      
      // Get the file path
      final filePath = item['file_path'];
      
      if (filePath == null) {
        EVLogger.warning('Item has no associated file path', {
          'itemId': itemId,
        });
        return null;
      }
      
      // Get the file content
      return await _fileService.getFileContent(filePath);
    } catch (e) {
      EVLogger.error('Failed to get offline file content', {
        'itemId': itemId,
        'error': e.toString(),
      });
      return null;
    }
  }
  
  /// Get all offline items under a parent
  Future<List<BrowseItem>> getOfflineItems(String? parentId) async {
    try {
      // Get items from database
      final items = await _database.getItemsByParent(parentId);
      
      // Convert to BrowseItem objects
      return items.map((data) => BrowseItem(
        id: data['id'],
        name: data['name'],
        type: data['type'],
        isDepartment: data['is_department'] == 1,
        description: data['description'],
        modifiedDate: data['modified_date'],
        modifiedBy: data['modified_by'],
      )).toList();
    } catch (e) {
      EVLogger.error('Failed to get offline items', {
        'parentId': parentId,
        'error': e.toString(),
      });
      return [];
    }
  }
  
  /// Remove an item from offline storage
  ///
  /// If recursive is true and the item is a folder, also removes all children
  Future<bool> removeOffline(String itemId, {bool recursive = true}) async {
    try {
      // Get the item metadata
      final item = await _database.getItem(itemId);
      
      if (item == null) {
        EVLogger.warning('Item not found in offline database', {
          'itemId': itemId,
        });
        return false;
      }
      
      // If this is a document with a file path, delete the file
      final filePath = item['file_path'];
      if (filePath != null) {
        await _fileService.deleteFile(filePath);
      }
      
      // If recursive and this is a folder, remove all children
      if (recursive && (item['type'] == 'folder' || item['is_department'] == 1)) {
        await _database.removeItemsWithParent(itemId);
      }
      
      // Remove the item itself
      await _database.removeItem(itemId);
      
      EVLogger.info('Item removed from offline storage', {
        'itemId': itemId,
        'recursive': recursive,
      });
      
      return true;
    } catch (e) {
      EVLogger.error('Failed to remove offline item', {
        'itemId': itemId,
        'error': e.toString(),
      });
      return false;
    }
  }
  
  /// Get the total storage used by offline files
  Future<String> getStorageUsage() async {
    final bytes = await _fileService.calculateTotalStorageUsed();
    
    // Convert bytes to a human-readable format
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
  
  /// Clear all offline content
  Future<void> clearAllOfflineContent() async {
    try {
      // Clear database
      final database = await _database.database;
      await database.delete('offline_items');
      
      // Clear files
      await _fileService.clearAllFiles();
      
      EVLogger.info('All offline content cleared');
    } catch (e) {
      EVLogger.error('Failed to clear all offline content', e);
      rethrow;
    }
  }
}
