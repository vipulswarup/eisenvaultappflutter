import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_core.dart' show OfflineStorageProvider, OfflineEvent;
import 'package:eisenvaultappflutter/services/offline/offline_storage_provider.dart' show LocalStorageProvider;
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_file_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_config.dart';
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
  
  
  // Storage keys for credentials
  static const String _keyInstanceType = 'offline_instance_type';
  static const String _keyBaseUrl = 'offline_base_url';
  static const String _keyAuthToken = 'offline_auth_token';
  static const String _keyUsername = 'offline_username';
  
  // Connectivity monitoring
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  
  // Event controller for offline state changes
  final _eventController = StreamController<OfflineEvent>.broadcast();
  
  /// Stream of offline events
  Stream<OfflineEvent> get events => _eventController.stream;
  
  final _connectivityStream = StreamController<bool>.broadcast();
  
  Stream<bool> get onConnectivityChanged => _connectivityStream.stream;
  
  /// Factory method to create an OfflineManager with default providers
  static Future<OfflineManager> createDefault({
    OfflineConfig? config,
    sync.OfflineSyncProvider? syncProvider,
    bool requireCredentials = true,
  }) async {
    final storage = FlutterSecureStorage();
    final instanceType = await storage.read(key: _keyInstanceType);
    final baseUrl = await storage.read(key: _keyBaseUrl);
    final authToken = await storage.read(key: _keyAuthToken);

    if (requireCredentials && (instanceType == null || baseUrl == null || authToken == null)) {
      throw Exception('Missing required credentials for offline sync');
    }

    final provider = syncProvider ?? (instanceType != null && baseUrl != null && authToken != null
        ? _DefaultSyncProvider(
            instanceType: instanceType,
            baseUrl: baseUrl,
            authToken: authToken,
          )
        : null);

    return OfflineManager(
      storage: LocalStorageProvider(),
      metadata: _DatabaseMetadataAdapter(OfflineDatabaseService.instance),
      sync: provider ?? _DefaultSyncProvider(
        instanceType: '',
        baseUrl: '',
        authToken: '',
      ),
      config: config ?? const OfflineConfig(),
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
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      // Only consider ConnectivityResult.none as offline
      // ConnectivityResult.other can be VPN connections and should not be treated as offline
      if (!results.contains(ConnectivityResult.none) && _config.autoSync) {
        _sync.startSync();
      }
    });
  }
  
  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((results) {
      // Only consider ConnectivityResult.none as offline
      // ConnectivityResult.other can be VPN connections and should not be treated as offline
      _connectivityStream.add(results.contains(ConnectivityResult.none));
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
      
      
      // Initialize sync provider with credentials
      if (_sync is _DefaultSyncProvider) {
        final syncProvider = _sync ;
        syncProvider
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
  
  /// Check if the device is currently offline
  Future<bool> isOffline() async {

    
    // Check connectivity first
    final result = await _connectivity.checkConnectivity();
    // Only consider ConnectivityResult.none as offline
    // ConnectivityResult.other can be VPN connections and should not be treated as offline
    final noConnectivity = result == ConnectivityResult.none;
    
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
  Future<bool> keepOffline(
    BrowseItem item, {
    String? parentId,
    DownloadManager? downloadManager,
    void Function(String message)? onError,
    int? totalFiles,
    int? currentFileIndex,
  }) async {
    try {
      // Create an OfflineItem from the BrowseItem, set parentId
      final offlineItem = OfflineItem.fromBrowseItem(item, parentId: parentId);
      
      // Save metadata
      await _metadata.saveItem(offlineItem);
      
      if (item.type == 'folder' || item.isDepartment) {
        // Only start download if this is the root folder/department being processed
        // (i.e., when totalFiles is provided, meaning we're in a batch operation)
        if (totalFiles != null && currentFileIndex != null) {
          // This is part of a larger download operation, don't start/complete download here
          try {
            // For sites/departments, we need to handle them specially
            if (item.isDepartment) {
              await _downloadSiteContents(
                item,
                downloadManager: downloadManager,
                onError: onError,
                totalFiles: totalFiles,
                currentFileIndex: currentFileIndex,
              );
            } else {
              // For regular folders, use the existing recursive approach
              await _downloadFolderContents(
                item,
                downloadManager: downloadManager,
                onError: onError,
                totalFiles: totalFiles,
                currentFileIndex: currentFileIndex,
              );
            }
            return true;
          } catch (e) {
            EVLogger.error('Error keeping folder offline', e);
            if (onError != null) {
              onError('Failed to download folder: ${item.name}\n${e.toString()}');
            }
            rethrow;
          }
        } else {
          // This is a standalone folder download, start the download process
          downloadManager?.startDownload();
          try {
            // For sites/departments, we need to handle them specially
            if (item.isDepartment) {
              await _downloadSiteContents(
                item,
                downloadManager: downloadManager,
                onError: onError,
              );
            } else {
              // For regular folders, use the existing recursive approach
              await _downloadFolderContents(
                item,
                downloadManager: downloadManager,
                onError: onError,
              );
            }
            downloadManager?.completeDownload();
            return true;
          } catch (e) {
            downloadManager?.completeDownload();
            EVLogger.error('Error keeping folder offline', e);
            if (onError != null) {
              onError('Failed to download folder: ${item.name}\n${e.toString()}');
            }
            rethrow;
          }
        }
      } else {
        // For files, we need to download the content
        final progress = DownloadProgress(
          fileName: item.name,
          progress: 0,
          totalFiles: totalFiles ?? 1,
          currentFileIndex: currentFileIndex ?? 1,
        );
        downloadManager?.startDownload();
        downloadManager?.updateProgress(progress);
        try {
          // Download content using sync provider
          final content = await _sync.downloadContent(item.id);
          
          // Update progress to 50% when download is complete
          downloadManager?.updateProgress(progress.copyWith(progress: 0.5));
          
          // Store the file content
          final filePath = await _storage.storeFile(item.id, content);
          
          // Update metadata with file path
          final updatedItem = offlineItem.copyWith(filePath: filePath);
          await _metadata.saveItem(updatedItem);
          
          // Update progress to 100% and increment file index
          final nextFileIndex = (currentFileIndex ?? 1) + 1;
          downloadManager?.updateProgress(progress.copyWith(
            progress: 1.0,
            currentFileIndex: nextFileIndex,
          ));
          
          // Only complete the download if this is the last file
          if (currentFileIndex == totalFiles) {
            downloadManager?.completeDownload();
          }
          
          _eventController.add(OfflineEvent('item_added', 'Item added to offline storage', updatedItem));
          return true;
        } catch (e) {
          downloadManager?.completeDownload();
          EVLogger.error('Error keeping file offline', e);
          if (onError != null) {
            onError('Failed to download file: ${item.name}\n${e.toString()}');
          }
          rethrow;
        }
      }
    } catch (e) {
      EVLogger.error('Error keeping item offline', e);
      if (onError != null) {
        onError('Error keeping item offline: ${item.name}\n${e.toString()}');
      }
      rethrow;
    }
  }
  
  /// Downloads the contents of a site with pagination
  Future<void> _downloadSiteContents(
    BrowseItem site, {
    DownloadManager? downloadManager,
    void Function(String message)? onError,
    int? totalFiles,
    int? currentFileIndex,
  }) async {
    try {
      // First get all containers for the site using the correct API endpoint
      final browseService = BrowseServiceFactory.getService(
        _sync.instanceType,
        _sync.baseUrl,
        _sync.authToken,
      );

      int skipCount = 0;
      const int maxItems = 25;
      List<BrowseItem> containers;
      int actualTotalFiles = totalFiles ?? 0;
      int actualCurrentFileIndex = currentFileIndex ?? 1; // Use 1-based indexing
      
      // If totalFiles is not provided, we need to count them first
      if (totalFiles == null) {
        // First pass: count total files
        do {
          containers = await browseService.getChildren(
            site,
            skipCount: skipCount,
            maxItems: maxItems,
          );

          for (final container in containers) {
            if (container.type == 'folder') {
              // For folders, we need to count their contents
              actualTotalFiles += await _countFolderContents(container);
            } else {
              actualTotalFiles++;
            }
          }

          skipCount += maxItems;
        } while (containers.length >= maxItems);

        // Reset skip count for actual download
        skipCount = 0;
      }
      
      // Second pass: download files
      do {
        containers = await browseService.getChildren(
          site,
          skipCount: skipCount,
          maxItems: maxItems,
        );

        // Process each container
        for (final container in containers) {
          if (container.type == 'folder') {
            // For folders, just save the folder metadata and then download its contents
            // Don't call keepOffline here as it would cause double downloads
            final offlineItem = OfflineItem.fromBrowseItem(container, parentId: site.id);
            await _metadata.saveItem(offlineItem);
            
            // Download folder contents
            await _downloadFolderContents(
              container,
              downloadManager: downloadManager,
              onError: onError,
              totalFiles: actualTotalFiles,
              currentFileIndex: actualCurrentFileIndex,
              parentId: container.id, // Use the container's ID as parent for its contents
            );
            // Update currentFileIndex based on folder contents
            actualCurrentFileIndex += await _countFolderContents(container);
          } else {
            // For files directly in site containers, download them
            await keepOffline(
              container,
              parentId: site.id,
              downloadManager: downloadManager,
              onError: onError,
              totalFiles: actualTotalFiles,
              currentFileIndex: actualCurrentFileIndex,
            );
            actualCurrentFileIndex++; // Increment after the file is processed
          }
        }

        skipCount += maxItems;
      } while (containers.length >= maxItems);
    } catch (e) {
      EVLogger.error('Error downloading site contents', e);
      if (onError != null) {
        onError('Failed to download site contents: ${site.name}\n${e.toString()}');
      }
      rethrow;
    }
  }
  
  /// Counts the total number of files in a folder (recursively)
  Future<int> _countFolderContents(BrowseItem folder) async {
    int count = 0;
    final browseService = BrowseServiceFactory.getService(
      _sync.instanceType,
      _sync.baseUrl,
      _sync.authToken,
    );

    int skipCount = 0;
    const int maxItems = 25;
    List<BrowseItem> contents;
    
    do {
      contents = await browseService.getChildren(
        folder,
        skipCount: skipCount,
        maxItems: maxItems,
      );

      for (final content in contents) {
        if (content.type == 'folder') {
          count += await _countFolderContents(content);
        } else {
          count++;
        }
      }

      skipCount += maxItems;
    } while (contents.length >= maxItems);

    return count;
  }
  
  /// Downloads the contents of a folder recursively
  Future<void> _downloadFolderContents(
    BrowseItem folder, {
    DownloadManager? downloadManager,
    void Function(String message)? onError,
    int? totalFiles,
    int? currentFileIndex,
    String? parentId,
  }) async {
    try {
      final browseService = BrowseServiceFactory.getService(
        _sync.instanceType,
        _sync.baseUrl,
        _sync.authToken,
      );

      int skipCount = 0;
      const int maxItems = 25;
      List<BrowseItem> contents;
      int fileIndex = currentFileIndex ?? 1; // Use 1-based indexing
      do {
        if (downloadManager?.isCancelled == true) return;
        contents = await browseService.getChildren(
          folder,
          skipCount: skipCount,
          maxItems: maxItems,
        );

        for (final content in contents) {
          if (downloadManager?.isCancelled == true) return;
          if (content.type == 'folder') {
            // For folders, just save the folder metadata and then download its contents
            // Don't call keepOffline here as it would cause double downloads
            final offlineItem = OfflineItem.fromBrowseItem(content, parentId: parentId ?? folder.id);
            await _metadata.saveItem(offlineItem);
            
            // Then download its contents
            fileIndex = await _downloadFolderContentsWithIndex(
              content,
              downloadManager: downloadManager,
              onError: onError,
              totalFiles: totalFiles,
              currentFileIndex: fileIndex,
              parentId: content.id, // Use the folder's ID as parent for its contents
            );
          } else {
            await keepOffline(
              content,
              parentId: parentId ?? folder.id,
              downloadManager: downloadManager,
              onError: onError,
              totalFiles: totalFiles,
              currentFileIndex: fileIndex,
            );
            fileIndex++; // Increment after the file is processed
          }
        }

        skipCount += maxItems;
      } while (contents.length >= maxItems);
    } catch (e) {
      EVLogger.error('Error downloading folder contents', e);
      if (onError != null) {
        onError('Failed to download folder contents: ${folder.name}\n${e.toString()}');
      }
      rethrow;
    }
  }
  
  /// Helper that returns the updated file index after downloading a folder
  Future<int> _downloadFolderContentsWithIndex(
    BrowseItem folder, {
    DownloadManager? downloadManager,
    void Function(String message)? onError,
    int? totalFiles,
    int? currentFileIndex,
    String? parentId,
  }) async {
    int fileIndex = currentFileIndex ?? 1; // Use 1-based indexing
    final browseService = BrowseServiceFactory.getService(
      _sync.instanceType,
      _sync.baseUrl,
      _sync.authToken,
    );
    int skipCount = 0;
    const int maxItems = 25;
    List<BrowseItem> contents;
    do {
      if (downloadManager?.isCancelled == true) return fileIndex;
      contents = await browseService.getChildren(
        folder,
        skipCount: skipCount,
        maxItems: maxItems,
      );
      for (final content in contents) {
        if (downloadManager?.isCancelled == true) return fileIndex;
        if (content.type == 'folder') {
          // For folders, just save the folder metadata and then download its contents
          // Don't call keepOffline here as it would cause double downloads
          final offlineItem = OfflineItem.fromBrowseItem(content, parentId: parentId);
          await _metadata.saveItem(offlineItem);
          
          // Then download its contents
          fileIndex = await _downloadFolderContentsWithIndex(
            content,
            downloadManager: downloadManager,
            onError: onError,
            totalFiles: totalFiles,
            currentFileIndex: fileIndex,
            parentId: content.id, // Use the folder's ID as parent for its contents
          );
        } else {
          await keepOffline(
            content,
            parentId: parentId,
            downloadManager: downloadManager,
            onError: onError,
            totalFiles: totalFiles,
            currentFileIndex: fileIndex,
          );
          fileIndex++; // Increment after the file is processed
        }
      }
      skipCount += maxItems;
    } while (contents.length >= maxItems);
    return fileIndex;
  }
  
  /// Check if an item is available offline
  Future<bool> isItemOffline(String itemId) async {
    try {
      final metadata = await _metadata.getMetadata(itemId);
      return metadata != null;
    } catch (e) {
      EVLogger.error('Error checking if item is offline', e);
      return false;
    }
  }
  
  /// Get offline file content
  Future<Uint8List?> getFileContent(String itemId) async {
    
    
    try {
      final content = await _storage.getFile(itemId);
      if (content == null) {
        
      } else {
        
      }
      return content;
    } catch (e) {
      EVLogger.error('Error getting offline file content', e);
      return null;
    }
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
      await _database.getAllOfflineItems();
    } catch (e) {
      EVLogger.error('Failed to dump offline database', e);
    }
  }
  
  /// Clear all offline content (database and files)
  Future<void> clearAllOfflineContent() async {
    await Future.wait([
      _storage.clearStorage(),
      _database.clearAllItems(),
    ]);
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription.cancel();
    _eventController.close();
    _connectivityStream.close();
  }
  
  /// Get the total available space on the device
  Future<String> getAvailableSpace() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final result = await Process.run('df', ['-k', path]);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        if (lines.length > 1) {
          final values = lines[1].split(RegExp(r'\s+'));
          if (values.length > 3) {
            final availableBytes = int.parse(values[3]) * 1024; // Convert KB to bytes
            
            // Convert bytes to a human-readable format
            if (availableBytes < 1024) {
              return '$availableBytes B';
            } else if (availableBytes < 1024 * 1024) {
              return '${(availableBytes / 1024).toStringAsFixed(2)} KB';
            } else if (availableBytes < 1024 * 1024 * 1024) {
              return '${(availableBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
            } else {
              return '${(availableBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
            }
          }
        }
      }
      return 'Unknown';
    } catch (e) {
      EVLogger.error('Error getting available space', e);
      return 'Unknown';
    }
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
       
  // Add getters for credentials
  @override
  String get instanceType => _instanceType;
  
  @override
  String get baseUrl => _baseUrl;
  
  @override
  String get authToken => _authToken;
  
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

