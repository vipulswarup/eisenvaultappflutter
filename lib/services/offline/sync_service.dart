import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_file_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Service responsible for synchronizing offline content with the server
///
/// Monitors network connectivity and updates offline content
/// when internet connection is restored.
///
/// ## Conflict Resolution Strategy
/// 
/// This service uses a "server wins" approach to conflict resolution:
/// 
/// 1. When syncing, the service compares modification timestamps between the 
///    local cached version and the server version
/// 2. If the server version has a newer timestamp, it automatically replaces
///    the local version
/// 3. If the local version is newer or has the same timestamp, no action is taken
/// 
/// This approach assumes:
/// - All modifications happen on the server (read-only offline access)
/// - Server timestamps are reliable indicators of which version is most current
/// - No merging of changes is required
/// 
/// For more complex scenarios involving two-way sync or collaborative editing,
/// a more sophisticated conflict resolution strategy would be needed.
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
  
  // Callbacks - CHANGED FROM FINAL TO NON-FINAL
  Function()? onSyncStarted;
  Function()? onSyncCompleted;
  Function(String message)? onSyncProgress;
  Function(String error)? onSyncError;
  
  Timer? _periodicSyncTimer;
  
  /// Constructor
  SyncService({
    this.onSyncStarted,
    this.onSyncCompleted,
    this.onSyncProgress,
    this.onSyncError,
  });
  
  /// Initialize the sync service with authentication details
  void initialize({
    required String instanceType,
    required String baseUrl,
    required String authToken,
  }) {
    _instanceType = instanceType;
    _baseUrl = baseUrl;
    _authToken = authToken;
    
    // Start monitoring connectivity
    _startMonitoringConnectivity();
  }
  
  /// Start monitoring network connectivity changes
  void _startMonitoringConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      // Consider both ConnectivityResult.none and ConnectivityResult.other as offline states
      if (!results.contains(ConnectivityResult.none) && !results.contains(ConnectivityResult.other)) {
        _notifyProgress('Internet connection restored, syncing offline content...');
        Future.delayed(const Duration(seconds: 2), () {
          startSync();
        });
      }
    });
  }
  
  /// Manually trigger a sync operation
  Future<void> startSync() async {
    if (_instanceType == null || _baseUrl == null || _authToken == null) {
      _notifyError('Cannot sync: authentication details not set');
      return;
    }
    
    if (_isSyncing) {
      return;
    }
    
    _isSyncing = true;
    _notifySyncStarted();
    
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      // Consider both ConnectivityResult.none and ConnectivityResult.other as offline states
      if (connectivityResult == ConnectivityResult.none || connectivityResult == ConnectivityResult.other) {
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
  
  /// Perform the actual sync operation
  Future<void> _performSync() async {
    _notifyProgress('Checking for updates...');
    
    // Get all offline items from database
    final allItems = await _database.getAllOfflineItems();
    
    // Track progress
    int total = allItems.length;
    int current = 0;
    
    // Process each item
    for (var item in allItems) {
      current++;
      
      _notifyProgress('Syncing item $current/$total: ${item['name']}');
      
      try {
        // Get the item type and ID
        final String itemId = item['id'];
        final String itemType = item['type'];
        
        // Skip folders for now - we'll handle them through their parent-child relationships
        if (itemType == 'folder' || item['is_department'] == 1) {
          continue;
        }
        
        // For documents, check if they've been updated on the server
        await _syncDocument(
          itemId: itemId,
          currentModifiedDate: item['modified_date'],
          filePath: item['file_path'],
        );
      } catch (e) {
        EVLogger.error('Error syncing item', {
          'itemId': item['id'],
          'error': e.toString(),
        });
        // Continue with next item rather than failing the entire sync
      }
    }
    
    _notifyProgress('Sync completed successfully');
  }
  
  /// Sync a document by checking for updates and downloading if needed
  ///
  /// Uses a "server wins" conflict resolution strategy - if the server
  /// version is newer than our cached version, we download and replace
  /// the local copy.
  Future<void> _syncDocument({
    required String itemId,
    String? currentModifiedDate,
    String? filePath,
  }) async {
    if (filePath == null) {
      EVLogger.warning('Document has no file path, skipping sync', {
        'itemId': itemId,
      });
      return;
    }
    
    try {
      final documentService = DocumentServiceFactory.getService(
        _instanceType!,
        _baseUrl!,
        _authToken!,
      );
      
      final browseService = BrowseServiceFactory.getService(
        _instanceType!,
        _baseUrl!,
        _authToken!,
      );
      
      final latestMetadata = await browseService.getItemDetails(itemId);
      
      if (latestMetadata == null) {
        EVLogger.warning('Document no longer exists on server', {
          'itemId': itemId,
        });
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
      EVLogger.error('Failed to sync document', {
        'itemId': itemId,
        'error': e.toString(),
      });
    }
  }
  
  // Helper methods for callbacks
  void _notifySyncStarted() {
    if (onSyncStarted != null) {
      onSyncStarted!();
    }
  }
  
  void _notifySyncCompleted() {
    if (onSyncCompleted != null) {
      onSyncCompleted!();
    }
  }
  
  void _notifyProgress(String message) {
    if (onSyncProgress != null) {
      onSyncProgress!(message);
    }
  }
  
  void _notifyError(String error) {
    EVLogger.error('Sync error: $error');
    if (onSyncError != null) {
      onSyncError!(error);
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }

  // Add this method to SyncService
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