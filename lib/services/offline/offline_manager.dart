import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Add this import

import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_file_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Central manager for offline content functionality
class OfflineManager {
  // Services for database and file operations
  final OfflineDatabaseService _database = OfflineDatabaseService.instance;
  final OfflineFileService _fileService = OfflineFileService();
  
  // Connectivity for checking network status
  final Connectivity _connectivity = Connectivity();
  
  // Secure storage for credentials
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Storage keys for credentials
  static const String _keyInstanceType = 'offline_instance_type';
  static const String _keyBaseUrl = 'offline_base_url';
  static const String _keyAuthToken = 'offline_auth_token';
  static const String _keyUsername = 'offline_username';
  
  /// Save user credentials for offline access
  /// 
  /// These credentials will be used when the app is offline to
  /// display user information and authenticate with sync services
  /// when connectivity is restored.
  Future<void> saveCredentials({
    required String instanceType,
    required String baseUrl,
    required String authToken,
    required String username,
  }) async {
    try {
      EVLogger.info('Saving credentials for offline use', {
        'instanceType': instanceType,
        'baseUrl': baseUrl,
        'username': username,
      });
      
      // Store the credentials in secure storage
      await _secureStorage.write(key: _keyInstanceType, value: instanceType);
      await _secureStorage.write(key: _keyBaseUrl, value: baseUrl);
      await _secureStorage.write(key: _keyAuthToken, value: authToken);
      await _secureStorage.write(key: _keyUsername, value: username);
      
      EVLogger.debug('Credentials saved successfully');
      return;
    } catch (e) {
      EVLogger.error('Failed to save credentials for offline use', {
        'error': e.toString(),
      });
      rethrow;
    }
  }
  
  /// Get the saved credentials
  /// 
  /// Returns a map with the saved credentials or null if no credentials are saved
  Future<Map<String, String?>?> getSavedCredentials() async {
    try {
      final instanceType = await _secureStorage.read(key: _keyInstanceType);
      final baseUrl = await _secureStorage.read(key: _keyBaseUrl);
      final authToken = await _secureStorage.read(key: _keyAuthToken);
      final username = await _secureStorage.read(key: _keyUsername);
      
      // Return null if any of the required credentials are missing
      if (instanceType == null || baseUrl == null || authToken == null) {
        return null;
      }
      
      return {
        'instanceType': instanceType,
        'baseUrl': baseUrl,
        'authToken': authToken,
        'username': username,
      };
    } catch (e) {
      EVLogger.error('Failed to get saved credentials', {
        'error': e.toString(),
      });
      return null;
    }
  }
  
  /// Clear saved credentials
  Future<void> clearCredentials() async {
    try {
      await _secureStorage.delete(key: _keyInstanceType);
      await _secureStorage.delete(key: _keyBaseUrl);
      await _secureStorage.delete(key: _keyAuthToken);
      await _secureStorage.delete(key: _keyUsername);
      
      EVLogger.debug('Credentials cleared successfully');
    } catch (e) {
      EVLogger.error('Failed to clear credentials', {
        'error': e.toString(),
      });
      rethrow;
    }
  }

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
        
        try {
          // Get the document content from the server
          final documentService = DocumentServiceFactory.getService(
            instanceType,
            baseUrl,
            authToken,
          );
          
          // Download the document content
          final content = await documentService.getDocumentContent(item);
          
          // Ensure content is in the correct format
          final Uint8List bytes;
          if (content is Uint8List) {
            bytes = content;
          } else if (content is String) {
            // If it's a file path, read the file
            if (await File(content).exists()) {
              bytes = await File(content).readAsBytes();
            } else {
              // If it's raw string content, convert to bytes
              bytes = Uint8List.fromList(content.codeUnits);
            }
          } else {
            throw Exception('Unsupported content type: ${content.runtimeType}');
          }
          
          // Store the content and get the file path
          final filePath = await _fileService.storeFile(item.id, bytes);
          
          // Update the database with the file path
          await _database.updateItemFilePath(item.id, filePath);
          
          EVLogger.debug('Item inserted into offline database', {
            'itemId': item.id,
            'itemName': item.name,
          });
        } catch (e) {
          EVLogger.error('Failed to keep item offline', {
            'itemId': item.id,
            'itemName': item.name,
            'error': e.toString(),
          });
          // Remove the item from the database since we couldn't store its content
          await _database.removeItem(item.id);
          return false;
        }
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