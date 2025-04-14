import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_core.dart' show OfflineStorageProvider, OfflineEvent;
import 'package:eisenvaultappflutter/services/offline/offline_storage_provider.dart' show LocalStorageProvider;
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_file_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_config.dart';
import 'package:eisenvaultappflutter/services/offline/offline_exception.dart';
import 'package:eisenvaultappflutter/services/offline/offline_metadata_provider.dart';
import 'package:eisenvaultappflutter/services/offline/offline_sync_provider.dart' as sync;
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/services/offline/download_progress.dart';

/// Central manager for offline functionality
/// 
/// This class coordinates between storage, metadata, and sync providers
/// to provide a unified interface for offline operations.
class OfflineManager {
  final OfflineStorageProvider _storage;
  final OfflineMetadataProvider _metadata;
  final sync.OfflineSyncProvider _sync;
  final OfflineConfig _config;
  
  // Services for database and file operations
  final OfflineDatabaseService _database = OfflineDatabaseService.instance;
  final OfflineFileService _fileService = OfflineFileService();
  
  // Connectivity for checking network status
  final Connectivity _connectivity = Connectivity();
  
  // Secure storage for credentials
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Authentication details
  String? _instanceType;
  String? _baseUrl;
  String? _authToken;
  
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
  
  final _connectivityStream = StreamController<bool>.broadcast();
  
  Stream<bool> get onConnectivityChanged => _connectivityStream.stream;
  
  /// Factory method to create an OfflineManager with default providers
  static Future<OfflineManager> createDefault({
    OfflineConfig? config,
    sync.OfflineSyncProvider? syncProvider,
  }) async {
    final storage = FlutterSecureStorage();
    final instanceType = await storage.read(key: _keyInstanceType);
    final baseUrl = await storage.read(key: _keyBaseUrl);
    final authToken = await storage.read(key: _keyAuthToken);

    if (instanceType == null || baseUrl == null || authToken == null) {
      throw Exception('Missing required credentials for offline sync');
    }

    final provider = syncProvider ?? _DefaultSyncProvider(
      instanceType: instanceType,
      baseUrl: baseUrl,
      authToken: authToken,
    );

    return OfflineManager(
      storage: LocalStorageProvider(),
      metadata: _DatabaseMetadataAdapter(OfflineDatabaseService.instance),
      sync: provider,
      config: config ?? const OfflineConfig(),
    );
  }
  
  /// Create a default sync provider
  sync.OfflineSyncProvider _createDefaultSyncProvider() {
    return _DefaultSyncProvider(
      instanceType: _instanceType ?? '',
      baseUrl: _baseUrl ?? '',
      authToken: _authToken ?? ''
    );
  }
  
  OfflineManager({
    required OfflineStorageProvider storage,
    required OfflineMetadataProvider metadata,
    required sync.OfflineSyncProvider sync,
    required OfflineConfig config,
  }) : _storage = storage,
       _metadata = metadata,
       _sync = sync,
       _config = config {
    _initConnectivityMonitoring();
    _initConnectivityListener();
  }
  
  void _initConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && _config.autoSync) {
        _sync.startSync();
      }
    });
  }
  
  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((result) {
      _connectivityStream.add(result == ConnectivityResult.none);
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
  }) async {
    try {
      _instanceType = instanceType;
      _baseUrl = baseUrl;
      _authToken = authToken;
      
      // Initialize sync provider with credentials
      if (_sync is _DefaultSyncProvider) {
        (_sync as _DefaultSyncProvider)
          .._instanceType = instanceType
          .._baseUrl = baseUrl
          .._authToken = authToken;
      }
      
      await _secureStorage.write(key: _keyInstanceType, value: instanceType);
      await _secureStorage.write(key: _keyBaseUrl, value: baseUrl);
      await _secureStorage.write(key: _keyAuthToken, value: authToken);
      await _secureStorage.write(key: _keyUsername, value: _instanceType);
    } catch (e) {
      EVLogger.error('Failed to save credentials', e);
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
      await _secureStorage.delete(key: 'instanceType');
      await _secureStorage.delete(key: 'baseUrl');
      await _secureStorage.delete(key: 'authToken');
      await _secureStorage.delete(key: 'username');
    } catch (e) {
      EVLogger.error('Failed to clear credentials', e);
      rethrow;
    }
  }

  /// Check if the device is currently offline
  Future<bool> isOffline() async {
    if (forceOfflineMode) {
      return true;
    }
    
    // Check connectivity first
    final result = await _connectivity.checkConnectivity();
    // Consider both ConnectivityResult.none and ConnectivityResult.other as offline states
    final noConnectivity = result == ConnectivityResult.none || result == ConnectivityResult.other;
    
    // If we have connectivity, we're not offline
    if (!noConnectivity) {
      return false;
    }
    
    // If we have no connectivity, check if we have offline content
    final hasContent = await hasOfflineContent();
    
    // We're only considered offline if we have no connectivity AND have offline content
    return hasContent;
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
  
  /// Keep an item available for offline access
  Future<bool> keepOffline(BrowseItem item) async {
    try {
      // Create an OfflineItem from the BrowseItem
      final offlineItem = OfflineItem.fromBrowseItem(item);
      
      // Save metadata
      await _metadata.saveItem(offlineItem);
      
      if (item.type == 'folder') {
        // For folders, we need to recursively download contents
        final downloadManager = DownloadManager();
        downloadManager.startDownload();
        
        try {
          // Get folder contents
          final contents = await _sync.getFolderContents(item.id);
          final totalFiles = contents.where((item) => item.type != 'folder').length;
          var currentFileIndex = 0;
          
          // Process each item in the folder
          for (final content in contents) {
            if (content.type == 'folder') {
              // Recursively handle subfolders
              await keepOffline(content);
            } else {
              // Download file content
              currentFileIndex++;
              final progress = DownloadProgress(
                fileName: content.name,
                progress: 0,
                totalFiles: totalFiles,
                currentFileIndex: currentFileIndex,
              );
              downloadManager.updateProgress(progress);
              
              try {
                // Download content using sync provider
                final fileContent = await _sync.downloadContent(content.id);
                
                // Store the file content
                final filePath = await _storage.storeFile(content.id, fileContent);
                
                // Create and save offline item for the file
                final fileOfflineItem = OfflineItem.fromBrowseItem(content);
                final updatedFileItem = fileOfflineItem.copyWith(filePath: filePath);
                await _metadata.saveItem(updatedFileItem);
                
                // Update progress to 100% for this file
                downloadManager.updateProgress(progress.copyWith(progress: 1.0));
              } catch (e) {
                EVLogger.error('Error downloading file in folder', {
                  'fileName': content.name,
                  'error': e.toString()
                });
                // Continue with next file even if one fails
              }
            }
          }
          
          downloadManager.completeDownload();
          _eventController.add(OfflineEvent('item_added', 'Folder added to offline storage', offlineItem));
          return true;
        } catch (e) {
          downloadManager.completeDownload();
          rethrow;
        }
      } else {
        // For files, we need to download the content
        final progress = DownloadProgress(
          fileName: item.name,
          progress: 0,
          totalFiles: 1,
          currentFileIndex: 1,
        );
        
        final downloadManager = DownloadManager();
        downloadManager.startDownload();
        downloadManager.updateProgress(progress);
        
        try {
          // Download content using sync provider
          final content = await _sync.downloadContent(item.id);
          
          // Store the file content
          final filePath = await _storage.storeFile(item.id, content);
          
          // Update metadata with file path
          final updatedItem = offlineItem.copyWith(filePath: filePath);
          await _metadata.saveItem(updatedItem);
          
          // Update progress to 100%
          downloadManager.updateProgress(progress.copyWith(progress: 1.0));
          downloadManager.completeDownload();
          
          _eventController.add(OfflineEvent('item_added', 'Item added to offline storage', updatedItem));
          return true;
        } catch (e) {
          downloadManager.completeDownload();
          rethrow;
        }
      }
    } catch (e) {
      EVLogger.error('Error keeping item offline', e);
      rethrow;
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
      final items = await _metadata.getItemsByParent(parentId);
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
      EVLogger.error('Failed to get offline items', e);
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
      EVLogger.info('All offline items in database', {
        'count': allItems.length,
        'items': allItems.map((item) => item['name']).toList(),
      });
    } catch (e) {
      EVLogger.error('Failed to dump offline database', e);
    }
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription.cancel();
    _eventController.close();
    _connectivityStream.close();
  }
}

/// Default implementation of OfflineSyncProvider
class _DefaultSyncProvider implements sync.OfflineSyncProvider {
  final _eventController = StreamController<OfflineEvent>.broadcast();
  String _instanceType;
  String _baseUrl;
  String _authToken;
  
  _DefaultSyncProvider({
    required String instanceType,
    required String baseUrl,
    required String authToken,
  }) : _instanceType = instanceType,
       _baseUrl = baseUrl,
       _authToken = authToken;
       
  // Add setters for updating credentials
  void updateCredentials({
    required String instanceType,
    required String baseUrl,
    required String authToken,
  }) {
    _instanceType = instanceType;
    _baseUrl = baseUrl;
    _authToken = authToken;
  }

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
  
  @override
  Future<Uint8List> downloadContent(String itemId) async {
    try {
      final browseService = BrowseServiceFactory.getService(
        _instanceType,
        _baseUrl,
        _authToken,
      );
      
      final item = await browseService.getItemDetails(itemId);
      if (item == null) {
        throw Exception('Item not found');
      }
      
      final documentService = DocumentServiceFactory.getService(
        _instanceType,
        _baseUrl,
        _authToken,
      );
      
      final content = await documentService.getDocumentContent(item);
      if (content is String) {
        // If content is a file path, read the file
        return await File(content).readAsBytes();
      } else if (content is Uint8List) {
        return content;
      } else {
        throw Exception('Unexpected content type');
      }
    } catch (e) {
      EVLogger.error('Error downloading content', e);
      rethrow;
    }
  }
  
  @override
  Future<List<BrowseItem>> getFolderContents(String folderId) async {
    try {
      final browseService = BrowseServiceFactory.getService(
        _instanceType,
        _baseUrl,
        _authToken,
      );
      
      final folder = await browseService.getItemDetails(folderId);
      if (folder == null) {
        throw Exception('Folder not found');
      }
      
      return await browseService.getChildren(folder);
    } catch (e) {
      EVLogger.error('Error getting folder contents', e);
      rethrow;
    }
  }
  
  void dispose() {
    _eventController.close();
  }
}

/// Adapter to make OfflineDatabaseService implement OfflineMetadataProvider
class _DatabaseMetadataAdapter implements OfflineMetadataProvider {
  final OfflineDatabaseService _database;
  
  _DatabaseMetadataAdapter(this._database);
  
  @override
  Future<void> saveItem(OfflineItem item) async {
    // Insert the item into the database
    await _database.insertItem(
      BrowseItem(
        id: item.id,
        name: item.name,
        type: item.type,
        isDepartment: item.type == 'department',
        description: item.description,
        modifiedDate: item.modifiedDate?.toIso8601String(),
        modifiedBy: item.modifiedBy,
      ),
      parentId: item.parentId,
      filePath: item.filePath,
      syncStatus: 'pending',
    );
  }
  
  @override
  Future<Map<String, dynamic>?> getMetadata(String itemId) async {
    return await _database.getItem(itemId);
  }
  
  @override
  Future<List<Map<String, dynamic>>> getItemsByParent(String? parentId) async {
    final items = await _database.getItemsByParent(parentId);
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

