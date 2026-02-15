import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_file_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';

/// Service responsible for synchronizing offline content with the server.
///
/// Uses a "server wins" conflict resolution strategy:
/// 1. Compares modification timestamps between local and server versions.
/// 2. If the server version is newer, replaces the local version.
/// 3. If a document no longer exists on the server, removes it locally.
///
/// Assumes read-only offline access (all modifications happen on the server).
class SyncService {
  // Dependencies
  final OfflineDatabaseService _database = OfflineDatabaseService.instance;
  final OfflineFileService _fileService = OfflineFileService();

  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Authentication details needed for API calls
  String? _instanceType;
  String? _baseUrl;
  String? _authToken;

  // Sync state
  bool _isSyncing = false;
  bool _cancelled = false;

  // Callbacks
  Function()? onSyncStarted;
  Function()? onSyncCompleted;
  Function(String message)? onSyncProgress;
  Function(String error)? onSyncError;

  Timer? _periodicSyncTimer;

  SyncService({
    this.onSyncStarted,
    this.onSyncCompleted,
    this.onSyncProgress,
    this.onSyncError,
  });

  /// Initialize the sync service with authentication details.
  void initialize({
    required String instanceType,
    required String baseUrl,
    required String authToken,
  }) {
    _instanceType = instanceType;
    _baseUrl = baseUrl;
    _authToken = authToken;
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        _notifyProgress('Internet connection restored, syncing offline content...');
        Future.delayed(const Duration(seconds: 2), () {
          startSync();
        });
      }
    });
  }

  /// Manually trigger a sync operation.
  Future<void> startSync() async {
    if (_instanceType == null || _baseUrl == null || _authToken == null) {
      _notifyError('Cannot sync: authentication details not set');
      return;
    }

    if (_isSyncing) return;

    _isSyncing = true;
    _cancelled = false;
    _notifySyncStarted();

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _notifyError('Cannot sync: device is offline');
        _isSyncing = false;
        return;
      }

      await _performSync();
      _notifySyncCompleted();
    } catch (e) {
      EVLogger.error('Sync failed', e);
      _notifyError('Sync failed: ${e.toString()}');
    } finally {
      _isSyncing = false;
    }
  }

  /// Perform the actual sync operation.
  ///
  /// Creates API services once and reuses them throughout the sync cycle.
  /// Runs two passes:
  ///   Pass 1: Update existing documents (check server modification dates).
  ///   Pass 2: For each offline folder, check for new files, new sub-folders,
  ///           and verify whether folders have been deleted on the server.
  Future<void> _performSync() async {
    _notifyProgress('Checking for updates...');

    // Create services once for the entire sync cycle
    final browseService = BrowseServiceFactory.getService(
      _instanceType!,
      _baseUrl!,
      _authToken!,
    );
    final documentService = DocumentServiceFactory.getService(
      _instanceType!,
      _baseUrl!,
      _authToken!,
    );

    // Create a single OfflineManager for any new-folder downloads
    OfflineManager? offlineManager;

    final allItems = await _database.getAllOfflineItems();
    int total = allItems.length;
    int current = 0;

    // --- Pass 1: Update existing documents ---
    for (var item in allItems) {
      if (_cancelled) return;
      current++;
      _notifyProgress('Syncing item $current/$total: ${item['name']}');

      try {
        final String itemType = item['type'];
        if (itemType == 'folder' || item['is_department'] == 1) continue;

        await _syncDocument(
          itemId: item['id'],
          currentModifiedDate: item['modified_date'],
          filePath: item['file_path'],
          browseService: browseService,
          documentService: documentService,
        );
      } catch (e) {
        EVLogger.error('Error syncing item', {
          'itemId': item['id'],
          'error': e.toString(),
        });
      }
    }

    // --- Pass 2: Check folders for new content and deletions ---
    _notifyProgress('Checking offline folders for changes...');

    final offlineFolderIds = allItems
        .where((item) => item['type'] == 'folder' || item['is_department'] == 1)
        .map((item) => item['id'] as String)
        .toSet();

    final existingOfflineIds = allItems.map((item) => item['id'] as String).toSet();

    for (final folderId in offlineFolderIds) {
      if (_cancelled) return;
      try {
        _notifyProgress('Checking folder for changes...');

        final folderItem = await browseService.getItemDetails(folderId);
        if (folderItem == null) {
          await _handlePossibleDeletion(folderId, browseService);
          continue;
        }

        // Paginate through ALL server children
        final serverChildren = await _getAllChildren(browseService, folderItem);

        // Existing offline children for this folder
        final existingOfflineChildren = allItems
            .where((item) => item['parent_id'] == folderId)
            .map((item) => item['id'] as String)
            .toSet();

        // Download new files
        final newFiles = serverChildren
            .where((child) => child.type == 'file' && !existingOfflineChildren.contains(child.id))
            .toList();

        for (final newFile in newFiles) {
          try {
            await _downloadNewFile(newFile, folderId, documentService);
            _notifyProgress('Downloaded new file: ${newFile.name}');
          } catch (e) {
            EVLogger.error('Failed to download new file', {
              'fileId': newFile.id,
              'fileName': newFile.name,
              'error': e.toString(),
            });
          }
        }

        // Download new folders
        final newFolders = serverChildren
            .where((child) =>
                (child.type == 'folder' || child.isDepartment) &&
                !existingOfflineIds.contains(child.id))
            .toList();

        for (final newFolder in newFolders) {
          try {
            offlineManager ??= await OfflineManager.createDefault();
            await _downloadNewFolder(newFolder, folderId, offlineManager);
            _notifyProgress('Downloaded new folder: ${newFolder.name}');
          } catch (e) {
            EVLogger.error('Failed to download new folder', {
              'folderId': newFolder.id,
              'folderName': newFolder.name,
              'error': e.toString(),
            });
          }
        }
      } catch (e) {
        EVLogger.error('Error checking folder', {
          'folderId': folderId,
          'error': e.toString(),
        });

        if (_is404Error(e)) {
          await _handlePossibleDeletion(folderId, browseService);
        }
      }
    }

    _notifyProgress('Sync completed successfully');
  }

  /// Fetch all children of a folder using pagination.
  Future<List<BrowseItem>> _getAllChildren(
    BrowseService browseService,
    BrowseItem parent,
  ) async {
    final allChildren = <BrowseItem>[];
    int skipCount = 0;
    const int maxItems = 25;
    List<BrowseItem> page;

    do {
      page = await browseService.getChildren(
        parent,
        skipCount: skipCount,
        maxItems: maxItems,
      );
      allChildren.addAll(page);
      skipCount += maxItems;
    } while (page.length >= maxItems);

    return allChildren;
  }

  /// Sync a single document: re-download if server version is newer,
  /// remove from offline if it no longer exists on the server.
  Future<void> _syncDocument({
    required String itemId,
    String? currentModifiedDate,
    String? filePath,
    required BrowseService browseService,
    required DocumentService documentService,
  }) async {
    if (filePath == null) return;

    try {
      final latestMetadata = await browseService.getItemDetails(itemId);

      if (latestMetadata == null) {
        // Document deleted on server -- remove from offline storage
        EVLogger.info('Document deleted on server, removing from offline', {
          'itemId': itemId,
        });
        await _database.removeItem(itemId);
        await _fileService.deleteFile(itemId);
        return;
      }

      final String? serverModifiedDate = latestMetadata.modifiedDate;

      if (serverModifiedDate != null && currentModifiedDate != null) {
        final DateTime serverDate = DateTime.parse(serverModifiedDate);
        final DateTime localDate = DateTime.parse(currentModifiedDate);

        if (serverDate.isAfter(localDate)) {
          final content = await documentService.getDocumentContent(latestMetadata);
          await _fileService.storeFile(itemId, content);
          await _database.updateItemFilePath(itemId, filePath);
          _notifyProgress('Updated document: ${latestMetadata.name}');
        }
      }
    } catch (e) {
      if (_is404Error(e)) {
        EVLogger.info('Document returned 404, removing from offline', {
          'itemId': itemId,
        });
        await _database.removeItem(itemId);
        await _fileService.deleteFile(itemId);
      } else {
        EVLogger.error('Failed to sync document', {
          'itemId': itemId,
          'error': e.toString(),
        });
      }
    }
  }

  /// Handle a folder that might have been deleted on the server.
  /// Verifies before removing to avoid data loss from transient errors.
  Future<void> _handlePossibleDeletion(
    String folderId,
    BrowseService browseService,
  ) async {
    final isDeleted = await _isFolderTrulyDeleted(folderId, browseService);
    if (isDeleted) {
      EVLogger.warning('Folder confirmed as deleted, cleaning up', {
        'folderId': folderId,
      });
      await _cleanupDeletedFolder(folderId);
    } else {
      EVLogger.warning('Folder may still exist -- skipping cleanup', {
        'folderId': folderId,
      });
    }
  }

  /// Multi-step verification to confirm a folder was truly deleted on the server.
  /// Returns true only when confident the folder is gone; false otherwise
  /// (errs on the side of keeping data).
  Future<bool> _isFolderTrulyDeleted(
    String folderId,
    BrowseService browseService,
  ) async {
    try {
      // Step 1: Direct item lookup
      final folderItem = await browseService.getItemDetails(folderId);
      if (folderItem != null) return false; // Folder exists

      // Step 2: Check if a parent folder still lists this folder
      final dbItem = await _database.getItem(folderId);
      final parentId = dbItem?['parent_id'] as String?;
      if (parentId != null) {
        try {
          final parentItem = await browseService.getItemDetails(parentId);
          if (parentItem != null) {
            final parentChildren = await _getAllChildren(browseService, parentItem);
            if (parentChildren.any((child) => child.id == folderId)) {
              return false; // Folder found in parent's children
            }
          }
        } catch (e) {
          EVLogger.debug('Error checking parent folder', {
            'parentId': parentId,
            'folderId': folderId,
            'error': e.toString(),
          });
        }
      }

      // Step 3: Check if this folder has offline children -- be extra careful
      final folderChildren = await _database.getItemsByParent(folderId);
      if (folderChildren.isNotEmpty) {
        // The folder has children in our DB. Confirm via a 404 on getItemDetails.
        try {
          final recheckItem = await browseService.getItemDetails(folderId);
          if (recheckItem != null) return false;
        } catch (e) {
          if (!_is404Error(e)) return false; // Non-404 error -- be conservative
        }
      }

      // Step 4: Verify API is healthy by probing another offline folder
      final allItems = await _database.getAllOfflineItems();
      final otherFolder = allItems.firstWhere(
        (item) =>
            (item['type'] == 'folder' || item['type'] == 'department') &&
            item['id'] != folderId,
        orElse: () => <String, dynamic>{},
      );
      if (otherFolder.isNotEmpty) {
        try {
          final probeResult = await browseService.getItemDetails(otherFolder['id']);
          if (probeResult == null) {
            // API might be down -- don't delete
            return false;
          }
        } catch (e) {
          return false; // API issues -- be conservative
        }
      } else {
        // No other folder to verify API health against
        return false;
      }

      return true; // All checks passed -- folder is truly deleted
    } catch (e) {
      EVLogger.error('Error verifying folder deletion', {
        'folderId': folderId,
        'error': e.toString(),
      });
      return false;
    }
  }

  /// Recursively remove a deleted folder and all its descendants from offline storage.
  Future<void> _cleanupDeletedFolder(String folderId) async {
    try {
      final allItems = await _database.getAllOfflineItems();
      final itemsToRemove = <String>[];

      void findDescendants(String parentId) {
        for (final item in allItems) {
          if (item['parent_id'] == parentId) {
            final itemId = item['id'] as String;
            itemsToRemove.add(itemId);
            findDescendants(itemId);
          }
        }
      }

      itemsToRemove.add(folderId);
      findDescendants(folderId);

      for (final itemId in itemsToRemove) {
        try {
          await _database.removeItem(itemId);
          await _fileService.deleteFile(itemId);
        } catch (e) {
          EVLogger.error('Error removing item during folder cleanup', {
            'itemId': itemId,
            'error': e.toString(),
          });
        }
      }

      EVLogger.info('Cleaned up deleted folder and ${itemsToRemove.length - 1} descendants', {
        'folderId': folderId,
        'totalItemsRemoved': itemsToRemove.length,
      });
      _notifyProgress('Cleaned up deleted folder and ${itemsToRemove.length - 1} items');
    } catch (e) {
      EVLogger.error('Error cleaning up deleted folder', {
        'folderId': folderId,
        'error': e.toString(),
      });
    }
  }

  /// Download a new file and add it to offline storage.
  Future<void> _downloadNewFile(
    BrowseItem file,
    String parentId,
    DocumentService documentService,
  ) async {
    final content = await documentService.getDocumentContent(file);
    final filePath = await _fileService.storeFile(file.id, content);
    await _database.insertItem(
      file,
      parentId: parentId,
      filePath: filePath,
      syncStatus: 'synced',
    );
  }

  /// Download a new folder and its contents using a shared OfflineManager.
  Future<void> _downloadNewFolder(
    BrowseItem folder,
    String parentId,
    OfflineManager offlineManager,
  ) async {
    await _database.insertItem(
      folder,
      parentId: parentId,
      syncStatus: 'synced',
    );
    await offlineManager.keepOffline(folder, parentId: parentId);
  }

  /// Check whether an error represents a 404 (not found) response.
  bool _is404Error(Object e) {
    final msg = e.toString();
    return msg.contains('404') || msg.contains('Not Found');
  }

  // --- Callback helpers ---

  void _notifySyncStarted() => onSyncStarted?.call();
  void _notifySyncCompleted() => onSyncCompleted?.call();
  void _notifyProgress(String message) => onSyncProgress?.call(message);

  void _notifyError(String error) {
    EVLogger.error('Sync error: $error');
    onSyncError?.call(error);
  }

  /// Cancel any in-flight sync and release resources.
  void dispose() {
    _cancelled = true;
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }

  void startPeriodicSync({Duration interval = const Duration(hours: 2)}) {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(interval, (_) async {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await startSync();
      }
    });
  }

  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }
}
