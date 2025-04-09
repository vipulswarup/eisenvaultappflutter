import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_file_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_storage_provider.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/services/offline/offline_core.dart';

/// Central manager for offline functionality
/// 
/// This class coordinates between storage, metadata, and sync providers
/// to provide a unified interface for offline operations.
class OfflineManager {
  final OfflineStorageProvider _storage;
  final OfflineMetadataProvider _metadata;
  final OfflineSyncProvider _sync;
  final OfflineConfig _config;
  
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
  
  // Connectivity monitoring
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  
  // Event controller for offline state changes
  final _eventController = StreamController<OfflineEvent>.broadcast();
  
  /// Stream of offline events
  Stream<OfflineEvent> get events => _eventController.stream;
  
  /// For testing: force offline mode regardless of actual connectivity
  static bool forceOfflineMode = false;
  
  /// Factory method to create an OfflineManager with default providers
  static OfflineManager createDefault() {
    return OfflineManager(
      storage: LocalStorageProvider(),
      metadata: _DatabaseMetadataAdapter(OfflineDatabaseService.instance),
      sync: _createDefaultSyncProvider(),
    );
  }
  
  /// Create a default sync provider
  static OfflineSyncProvider _createDefaultSyncProvider() {
    return _DefaultSyncProvider();
  }
  
  OfflineManager({
    required OfflineStorageProvider storage,
    required OfflineMetadataProvider metadata,
    required OfflineSyncProvider sync,
    OfflineConfig? config,
  }) : _storage = storage,
       _metadata = metadata,
       _sync = sync,
       _config = config ?? const OfflineConfig() {
    _initConnectivityMonitoring();
  }
  
  void _initConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && _config.autoSync) {
        _sync.startSync();
      }
    });
  }
  
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
    if (forceOfflineMode) {
      return true;
    }
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.none;
  }
  
  /// Check if offline content is available
  Future<bool> hasOfflineContent() async {
    try {
      // Get the list of offline items at the root level
      final items = await getOfflineItems(null);
      
      // If there are any items, offline content is available
      return items.isNotEmpty;
    } catch (e) {
      EVLogger.error('Error checking for offline content', e);
      return false;
    }
  }
  
  /// Keep an item available offline
  /// 
  /// @param item The item to keep offline
  /// @param parentId The parent ID of the item (for maintaining hierarchy)
  /// @param recursiveForFolders Whether to recursively download folder contents
  /// @param browseService Optional browse service for recursive folder download
  Future<bool> keepOffline(
    BrowseItem item, {
    String? parentId,
    bool recursiveForFolders = true,
    dynamic browseService,
  }) async {
    try {
      // Check storage space
      final usedSpace = await _storage.getStorageUsed();
      if (usedSpace >= _config.maxStorageBytes) {
        _eventController.add(const OfflineEvent(
          'error',
          'Not enough storage space for offline content',
        ));
        return false;
      }
      
      EVLogger.debug('Keeping item offline', {
        'id': item.id,
        'name': item.name,
        'type': item.type,
        'parentId': parentId,
      });
      
      // Store metadata first
      await _metadata.storeMetadata(item.id, {
        'id': item.id,
        'name': item.name,
        'type': item.type,
        'is_department': item.isDepartment,
        'description': item.description,
        'modified_date': item.modifiedDate,
        'modified_by': item.modifiedBy,
        'parent_id': parentId, // Important: Store parent ID for hierarchy
        'status': OfflineStatus.pending.toString(),
      });
      
      // If it's a folder and recursive download is enabled, download its contents
      if ((item.type == 'folder' || item.isDepartment) && 
          recursiveForFolders && 
          browseService != null) {
        try {
          // Get folder contents
          final contents = await browseService.getFolderContents(item.id);
          
          // Keep each item offline
          for (final childItem in contents.items) {
            await keepOffline(
              childItem,
              parentId: item.id,
              recursiveForFolders: true,
              browseService: browseService,
            );
          }
        } catch (e) {
          EVLogger.error('Failed to recursively download folder contents', {
            'folderId': item.id,
            'error': e.toString(),
          });
          // Continue with the current item even if recursive download fails
        }
      }
      
      // Start sync for this item
      await _sync.startSync();
      
      return true;
    } catch (e) {
      EVLogger.error('Failed to keep item offline', e);
      return false;
    }
  }
  
  /// Check if an item is available offline
  Future<bool> isAvailableOffline(String itemId) async {
    final metadata = await _metadata.getMetadata(itemId);
    return metadata != null;
  }
  
  /// Get offline file content
  Future<Uint8List?> getFileContent(String itemId) async {
    return await _storage.getFile(itemId);
  }
  
  /// Get all offline items under a parent
  Future<List<BrowseItem>> getOfflineItems(String? parentId) async {
    try {
      EVLogger.debug('Getting offline items', {'parentId': parentId});
      final items = await _metadata.getItemsByParent(parentId);
      
      EVLogger.debug('Retrieved offline items', {
        'parentId': parentId,
        'count': items.length,
        'itemNames': items.map((item) => item['name']).toList(),
      });
      
      return items.map((data) => BrowseItem(
        id: data['id'],
        name: data['name'],
        type: data['type'],
        isDepartment: data['is_department'] == true,
        description: data['description'],
        modifiedDate: data['modified_date'],
        modifiedBy: data['modified_by'],
      )).toList();
    } catch (e) {
      EVLogger.error('Error getting offline items', {
        'parentId': parentId,
        'error': e.toString(),
      });
      return [];
    }
  }
  
  /// Remove an item from offline storage
  Future<bool> removeOffline(String itemId) async {
    try {
      await Future.wait([
        _storage.deleteFile(itemId),
        _metadata.deleteMetadata(itemId),
      ]);
      return true;
    } catch (e) {
      EVLogger.error('Failed to remove offline item', e);
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
  Future<void> clearOfflineContent() async {
    await Future.wait([
      _storage.clearStorage(),
      _metadata.clearMetadata(),
    ]);
  }
  
  /// Debug function to dump all offline database contents
  Future<void> dumpOfflineDatabase() async {
    try {
      final allItems = await _database.getAllOfflineItems();
      EVLogger.debug('All offline items in database', {
        'count': allItems.length,
        'items': allItems.map((item) => {
          'id': item['id'],
          'name': item['name'],
          'type': item['type'],
          'parent_id': item['parent_id'],
        }).toList()
      });
    } catch (e) {
      EVLogger.error('Failed to dump offline database', e);
    }
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription.cancel();
    _eventController.close();
  }
}

/// Default implementation of OfflineSyncProvider
class _DefaultSyncProvider implements OfflineSyncProvider {
  final _eventController = StreamController<OfflineEvent>.broadcast();
  
  @override
  Future<void> startSync() async {
    // Default implementation
  }
  
  @override
  Future<void> stopSync() async {
    // Default implementation
  }
  
  @override
  Stream<OfflineEvent> get syncEvents => _eventController.stream;
  
  void dispose() {
    _eventController.close();
  }
}

/// Adapter to make OfflineDatabaseService implement OfflineMetadataProvider
class _DatabaseMetadataAdapter implements OfflineMetadataProvider {
  final OfflineDatabaseService _database;
  
  _DatabaseMetadataAdapter(this._database);
  
  @override
  Future<void> storeMetadata(String itemId, Map<String, dynamic> metadata) async {
    // Create a BrowseItem from the metadata
    final item = BrowseItem(
      id: metadata['id'],
      name: metadata['name'],
      type: metadata['type'],
      isDepartment: metadata['is_department'] == true,
      description: metadata['description'],
      modifiedDate: metadata['modified_date'],
      modifiedBy: metadata['modified_by'],
    );
    
    // Insert the item into the database
    await _database.insertItem(
      item,
      parentId: metadata['parent_id'],
      filePath: metadata['file_path'],
      syncStatus: metadata['status'] ?? 'pending',
    );
  }
  
  @override
  Future<Map<String, dynamic>?> getMetadata(String itemId) async {
    return await _database.getItem(itemId);
  }
  
  
    @override
  Future<List<Map<String, dynamic>>> getItemsByParent(String? parentId) async {
    final items = await _database.getItemsByParent(parentId);
    EVLogger.debug('Retrieved items by parent from database', {
      'parentId': parentId,
      'count': items.length,
    });
    return items;
  }
  
  @override
  Future<void> deleteMetadata(String itemId) async {
    await _database.removeItem(itemId);
  }
  
  @override
  Future<void> clearMetadata() async {
    // Since there's no direct method to clear all metadata,
    // we'll get all items and remove them one by one
    final items = await _database.getAllOfflineItems();
    for (final item in items) {
      await _database.removeItem(item['id']);
    }
  }
}

