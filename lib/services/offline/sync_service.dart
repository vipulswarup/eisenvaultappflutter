import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/document/document_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_file_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';

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
    _initConnectivityListener();
  }
  
  /// Start monitoring network connectivity changes
  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      // Only consider ConnectivityResult.none as offline
      // ConnectivityResult.other can be VPN connections and should not be treated as offline
      if (!results.contains(ConnectivityResult.none)) {
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
      // Only consider ConnectivityResult.none as offline
      // ConnectivityResult.other can be VPN connections and should not be treated as offline
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
  
  /// Perform the actual sync operation
  Future<void> _performSync() async {
    _notifyProgress('Checking for updates...');
    
    // Get all offline items from database
    final allItems = await _database.getAllOfflineItems();
    
    // Track progress
    int total = allItems.length;
    int current = 0;
    
    // First pass: Update existing files
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
    
    // Second pass: Check for new files in offline folders
    _notifyProgress('Checking for new files in offline folders...');
    await _checkForNewFiles(allItems);
    
    // Third pass: Check for new folders and verify deleted folders
    _notifyProgress('Checking for new folders and verifying deletions...');
    await _checkForNewFoldersAndDeletions(allItems);
    
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
  
  /// Verify if a folder is truly deleted by trying multiple approaches
  Future<bool> _isFolderTrulyDeleted(String folderId, dynamic browseService) async {
    EVLogger.debug('Starting folder deletion verification', {
      'folderId': folderId,
      'step': 'verification_start',
    });
    
    try {
      // First try: Direct item details
      EVLogger.debug('Step 1: Trying getItemDetails', {
        'folderId': folderId,
        'step': 'getItemDetails',
      });
      
      final folderItem = await browseService.getItemDetails(folderId);
      if (folderItem == null) {
        EVLogger.debug('getItemDetails returned null, trying alternative methods', {
          'folderId': folderId,
          'step': 'getItemDetails_null',
        });
      } else {
        EVLogger.debug('getItemDetails succeeded, but item might be in trash', {
          'folderId': folderId,
          'folderName': folderItem.name,
          'step': 'getItemDetails_success_but_check_trash',
        });
      }
      
      // Second try: Check if the folder appears in its parent's children list
      // This is the most reliable way to detect if a folder is in trash
      try {
        EVLogger.debug('Step 2: Checking if folder appears in parent\'s children', {
          'folderId': folderId,
          'step': 'check_parent_children',
        });
        
        // Get the folder's parent ID from our offline database
        final folderData = await _database.getItem(folderId);
        if (folderData != null && folderData['parent_id'] != null) {
          final parentId = folderData['parent_id'] as String;
          EVLogger.debug('Found parent ID for folder', {
            'folderId': folderId,
            'parentId': parentId,
            'step': 'found_parent_id',
          });
          
          // Get the parent folder details
          final parentFolder = await browseService.getItemDetails(parentId);
          if (parentFolder != null) {
            EVLogger.debug('Got parent folder details', {
              'parentId': parentId,
              'parentName': parentFolder.name,
              'step': 'got_parent_details',
            });
            
            // Get all children of the parent
            final parentChildren = await browseService.getChildren(parentFolder);
            EVLogger.debug('Got parent children', {
              'parentId': parentId,
              'childrenCount': parentChildren.length,
              'childrenIds': parentChildren.map((c) => c.id).toList(),
              'step': 'got_parent_children',
            });
            
            // Check if our folder appears in the parent's children
            final folderInParent = parentChildren.any((child) => child.id == folderId);
            
            if (folderInParent) {
              EVLogger.debug('Folder found in parent\'s children - not deleted', {
                'folderId': folderId,
                'parentId': parentId,
                'step': 'folder_in_parent_not_deleted',
              });
              return false; // Folder exists in parent's children
            } else {
              EVLogger.debug('Folder NOT found in parent\'s children - likely deleted/trashed', {
                'folderId': folderId,
                'parentId': parentId,
                'step': 'folder_not_in_parent_likely_deleted',
              });
              // Continue to additional checks
            }
          } else {
            EVLogger.debug('Could not get parent folder details', {
              'parentId': parentId,
              'step': 'parent_details_failed',
            });
          }
        } else {
          EVLogger.debug('No parent ID found for folder', {
            'folderId': folderId,
            'step': 'no_parent_id',
          });
        }
      } catch (e) {
        EVLogger.debug('Error checking parent children', {
          'folderId': folderId,
          'error': e.toString(),
          'step': 'parent_children_check_error',
        });
      }
      
      // Third try: Check if we can find this folder in any parent's children list
      // This is a more expensive check, so we'll only do it if the first two fail
      try {
        EVLogger.debug('Step 3: Checking all possible parents', {
          'folderId': folderId,
          'step': 'check_all_parents',
        });
        
        // Get all possible parent folders from the server
        // This is expensive but thorough
        final allItems = await _database.getAllOfflineItems();
        for (final item in allItems) {
          if (item['type'] == 'folder' || item['is_department'] == 1) {
            try {
              final parentFolder = BrowseItem(
                id: item['id'],
                name: item['name'],
                type: item['type'],
                isDepartment: item['is_department'] == 1,
              );
              final parentChildren = await browseService.getChildren(parentFolder);
              if (parentChildren.any((child) => child.id == folderId)) {
                EVLogger.debug('Folder found in server parent\'s children!', {
                  'folderId': folderId,
                  'parentId': item['id'],
                  'parentName': item['name'],
                  'step': 'found_in_server_parent',
                });
                return false; // Folder found in a parent's children
              }
            } catch (e) {
              EVLogger.debug('Error checking server parent folder', {
                'parentId': item['id'],
                'folderId': folderId,
                'error': e.toString(),
                'step': 'server_parent_check_error',
              });
              // Continue checking other parents
              continue;
            }
          }
        }
      } catch (e) {
        EVLogger.error('Error checking parent folders', {
          'folderId': folderId,
          'error': e.toString(),
          'step': 'parent_folders_check_error',
        });
      }
      
      // NEW: Additional conservative checks before marking as deleted
      // Check if this folder has any offline children - if it does, we should be extra careful
      final folderChildren = await _database.getItemsByParent(folderId);
      if (folderChildren.isNotEmpty) {
        // Check if we got a 404 error when trying to get children
        // If we did, it's a strong indication the folder is truly deleted
        bool has404Error = false;
        try {
          // Try to get children of this folder to see if it returns 404
          final folderItem = await browseService.getItemDetails(folderId);
          if (folderItem != null) {
            await browseService.getChildren(folderItem);
          }
        } catch (e) {
          if (e.toString().contains('404')) {
            has404Error = true;
            EVLogger.warning('Folder returned 404 for getChildren - strong indication it\'s deleted', {
              'folderId': folderId,
              'childrenCount': folderChildren.length,
              'step': '404_error_strong_deletion_indicator',
            });
          }
        }
        
        if (!has404Error) {
          EVLogger.warning('Folder has offline children - being conservative and assuming it still exists', {
            'folderId': folderId,
            'childrenCount': folderChildren.length,
            'step': 'has_offline_children_conservative',
          });
          return false; // Don't delete folders that have offline children (unless we got 404)
        } else {
          EVLogger.warning('Folder has offline children but returned 404 - proceeding with deletion', {
            'folderId': folderId,
            'childrenCount': folderChildren.length,
            'step': 'has_offline_children_but_404_deletion',
          });
          // Continue with deletion even though it has children
        }
      }
      
      // Check if we have any successful API calls to other folders
      // If we're getting 404s everywhere, it might be a server issue
      bool hasSuccessfulApiCalls = false;
      try {
        // Try to get a known good folder to see if API is working
        final rootFolder = await browseService.getItemDetails('12e6eb38-062c-42b8-9ef4-c499c1e03480'); // documentLibrary
        if (rootFolder != null) {
          hasSuccessfulApiCalls = true;
          EVLogger.debug('API is working - got root folder successfully', {
            'step': 'api_working_check',
          });
        }
      } catch (e) {
        EVLogger.warning('API might be having issues - being conservative', {
          'error': e.toString(),
          'step': 'api_issues_conservative',
        });
        return false; // If API is having issues, don't delete anything
      }
      
      // Only if we have successful API calls and the folder has no children
      // do we consider it truly deleted
      if (hasSuccessfulApiCalls) {
        EVLogger.debug('All verification steps failed and API is working - folder is likely deleted', {
          'folderId': folderId,
          'step': 'verification_failed_api_working',
        });
        return true;
      } else {
        EVLogger.warning('API issues detected - being conservative and assuming folder still exists', {
          'folderId': folderId,
          'step': 'api_issues_conservative_final',
        });
        return false;
      }
    } catch (e) {
      EVLogger.error('Error verifying folder deletion', {
        'folderId': folderId,
        'error': e.toString(),
        'step': 'verification_error',
      });
      // If we can't verify, assume the folder still exists to be safe
      return false;
    }
  }
  
  /// Check for new files in folders that are already offline
  Future<void> _checkForNewFiles(List<Map<String, dynamic>> allItems) async {
    EVLogger.debug('Starting check for new files', {
      'totalOfflineItems': allItems.length,
      'step': 'check_new_files_start',
    });
    
    try {
      final browseService = BrowseServiceFactory.getService(
        _instanceType!,
        _baseUrl!,
        _authToken!,
      );
      
      // Get all offline folder IDs
      final offlineFolderIds = allItems
          .where((item) => item['type'] == 'folder' || item['is_department'] == 1)
          .map((item) => item['id'])
          .toSet();
      
      EVLogger.debug('Found offline folders to check', {
        'folderIds': offlineFolderIds.toList(),
        'folderCount': offlineFolderIds.length,
        'step': 'found_offline_folders',
      });
      
      // Check each offline folder for new files
      for (final folderId in offlineFolderIds) {
        EVLogger.debug('Processing folder', {
          'folderId': folderId,
          'step': 'processing_folder',
        });
        
        try {
          _notifyProgress('Checking folder for new files...');
          
          // Get the folder item to pass to getChildren
          EVLogger.debug('Getting folder details', {
            'folderId': folderId,
            'step': 'get_folder_details',
          });
          
          final folderItem = await browseService.getItemDetails(folderId);
          if (folderItem == null) {
            EVLogger.debug('getItemDetails returned null, starting verification', {
              'folderId': folderId,
              'step': 'getItemDetails_null_start_verification',
            });
            
            // Verify if the folder is truly deleted before cleaning up
            final isDeleted = await _isFolderTrulyDeleted(folderId, browseService);
            EVLogger.debug('Verification result', {
              'folderId': folderId,
              'isDeleted': isDeleted,
              'step': 'verification_result',
            });
            
            if (isDeleted) {
              EVLogger.warning('Folder confirmed as deleted, cleaning up...', {
                'folderId': folderId,
                'step': 'cleanup_confirmed',
              });
              await _cleanupDeletedFolder(folderId);
            } else {
              EVLogger.warning('Could not get folder details, but folder may still exist - skipping for now', {
                'folderId': folderId,
                'reason': 'getItemDetails returned null but folder may still exist',
                'step': 'skip_folder_exists',
              });
            }
            continue;
          }
          
          EVLogger.debug('Folder details retrieved successfully', {
            'folderId': folderId,
            'folderName': folderItem.name,
            'step': 'folder_details_success',
          });
          
          // Get all children from the server
          EVLogger.debug('Getting folder children from server', {
            'folderId': folderId,
            'step': 'get_server_children',
          });
          
          final serverChildren = await browseService.getChildren(folderItem);
          
          EVLogger.debug('Got server children', {
            'folderId': folderId,
            'serverChildrenCount': serverChildren.length,
            'step': 'got_server_children',
          });
          
          // Get existing offline children for this folder
          final existingOfflineChildren = allItems
              .where((item) => item['parent_id'] == folderId)
              .map((item) => item['id'])
              .toSet();
          
          EVLogger.debug('Existing offline children', {
            'folderId': folderId,
            'existingChildrenCount': existingOfflineChildren.length,
            'existingChildren': existingOfflineChildren.toList(),
            'step': 'existing_offline_children',
          });
          
          // Find new files that aren't offline yet
          final newFiles = serverChildren
              .where((child) => 
                  child.type == 'file' && 
                  !existingOfflineChildren.contains(child.id))
              .toList();
          
          EVLogger.debug('Found new files', {
            'folderId': folderId,
            'newFilesCount': newFiles.length,
            'newFileNames': newFiles.map((f) => f.name).toList(),
            'step': 'found_new_files',
          });
          
          if (newFiles.isNotEmpty) {
            _notifyProgress('Found ${newFiles.length} new files, downloading...');
            
            // Download each new file
            for (final newFile in newFiles) {
              try {
                EVLogger.debug('Downloading new file', {
                  'fileId': newFile.id,
                  'fileName': newFile.name,
                  'folderId': folderId,
                  'step': 'download_new_file',
                });
                
                await _downloadNewFile(newFile, folderId);
                _notifyProgress('Downloaded new file: ${newFile.name}');
                
                EVLogger.debug('Successfully downloaded new file', {
                  'fileId': newFile.id,
                  'fileName': newFile.name,
                  'folderId': folderId,
                  'step': 'download_success',
                });
              } catch (e) {
                EVLogger.error('Failed to download new file', {
                  'fileId': newFile.id,
                  'fileName': newFile.name,
                  'error': e.toString(),
                  'step': 'download_failed',
                });
                // Continue with other files
              }
            }
          }
        } catch (e) {
          EVLogger.error('Error checking folder for new files', {
            'folderId': folderId,
            'error': e.toString(),
            'step': 'folder_check_error',
          });
          
          // Only clean up if we get a specific 404 error AND we can verify the folder is deleted
          if (e.toString().contains('404')) {
            EVLogger.warning('Folder returned 404, verifying if truly deleted...', {
              'folderId': folderId,
              'error': e.toString(),
              'step': '404_error_verification',
            });
            
            // Verify if the folder is truly deleted before cleaning up
            final isDeleted = await _isFolderTrulyDeleted(folderId, browseService);
            EVLogger.debug('404 verification result', {
              'folderId': folderId,
              'isDeleted': isDeleted,
              'step': '404_verification_result',
            });
            
            if (isDeleted) {
              EVLogger.warning('Folder confirmed as deleted, cleaning up...', {
                'folderId': folderId,
                'step': '404_cleanup_confirmed',
              });
              await _cleanupDeletedFolder(folderId);
            } else {
              EVLogger.warning('Folder returned 404 but may still exist - not cleaning up', {
                'folderId': folderId,
                'step': '404_no_cleanup',
              });
            }
          }
          // Continue with other folders
        }
      }
    } catch (e) {
      EVLogger.error('Error checking for new files', {
        'error': e.toString(),
        'step': 'check_new_files_error',
      });
    }
  }
  
  /// Clean up a deleted folder and all its contents from offline storage
  Future<void> _cleanupDeletedFolder(String folderId) async {
    try {
      // Get all items that belong to this folder (including subfolders and files)
      final allItems = await _database.getAllOfflineItems();
      final itemsToRemove = <String>[];
      
      // Find all items that are descendants of this folder
      void findDescendants(String parentId) {
        for (final item in allItems) {
          if (item['parent_id'] == parentId) {
            final itemId = item['id'];
            itemsToRemove.add(itemId);
            // Recursively find descendants of this item
            findDescendants(itemId);
          }
        }
      }
      
      // Start with the folder itself
      itemsToRemove.add(folderId);
      findDescendants(folderId);
      
      // Remove all items from database and storage
      for (final itemId in itemsToRemove) {
        try {
          await _database.removeItem(itemId);
          await _fileService.deleteFile(itemId);
        } catch (e) {
          EVLogger.error('Error removing deleted item from offline storage', {
            'itemId': itemId,
            'error': e.toString(),
          });
        }
      }
      
      EVLogger.info('Cleaned up deleted folder and ${itemsToRemove.length - 1} items', {
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
  
  /// Download a new file and add it to offline storage
  Future<void> _downloadNewFile(BrowseItem file, String parentId) async {
    try {
      final documentService = DocumentServiceFactory.getService(
        _instanceType!,
        _baseUrl!,
        _authToken!,
      );
      
      // Download the file content
      final content = await documentService.getDocumentContent(file);
      
      // Store the file
      final filePath = await _fileService.storeFile(file.id, content);
      
      // Add to database
      await _database.insertItem(
        file,
        parentId: parentId,
        filePath: filePath,
        syncStatus: 'synced',
      );
      
      EVLogger.info('Successfully downloaded new file', {
        'fileId': file.id,
        'fileName': file.name,
        'parentId': parentId,
      });
    } catch (e) {
      EVLogger.error('Failed to download new file', {
        'fileId': file.id,
        'fileName': file.name,
        'error': e.toString(),
      });
      rethrow;
    }
  }
  
  /// Check for new folders and verify deleted folders
  Future<void> _checkForNewFoldersAndDeletions(List<Map<String, dynamic>> allItems) async {
    EVLogger.debug('Starting check for new folders and deletions', {
      'totalOfflineItems': allItems.length,
      'step': 'check_folders_start',
    });
    
    try {
      final browseService = BrowseServiceFactory.getService(
        _instanceType!,
        _baseUrl!,
        _authToken!,
      );
      
      // Get all offline folder IDs
      final offlineFolderIds = allItems
          .where((item) => item['type'] == 'folder' || item['is_department'] == 1)
          .map((item) => item['id'])
          .toSet();
      
      EVLogger.debug('Found offline folders to check', {
        'folderIds': offlineFolderIds.toList(),
        'folderCount': offlineFolderIds.length,
        'step': 'found_offline_folders',
      });
      
      // Check each offline folder for deletion and get server children
      final Map<String, List<BrowseItem>> serverChildrenMap = {};
      
      for (final folderId in offlineFolderIds) {
        EVLogger.debug('Processing folder for deletion check', {
          'folderId': folderId,
          'step': 'processing_folder_deletion',
        });
        
        try {
          // Get the folder item to pass to getChildren
          final folderItem = await browseService.getItemDetails(folderId);
          if (folderItem == null) {
            EVLogger.debug('getItemDetails returned null, starting verification', {
              'folderId': folderId,
              'step': 'getItemDetails_null_start_verification',
            });
            
            // Verify if the folder is truly deleted before cleaning up
            final isDeleted = await _isFolderTrulyDeleted(folderId, browseService);
            EVLogger.debug('Verification result', {
              'folderId': folderId,
              'isDeleted': isDeleted,
              'step': 'verification_result',
            });
            
            if (isDeleted) {
              EVLogger.warning('Folder confirmed as deleted, cleaning up...', {
                'folderId': folderId,
                'step': 'cleanup_confirmed',
              });
              await _cleanupDeletedFolder(folderId);
            } else {
              EVLogger.warning('Could not get folder details, but folder may still exist - skipping for now', {
                'folderId': folderId,
                'reason': 'getItemDetails returned null but folder may still exist',
                'step': 'skip_folder_exists',
              });
            }
            continue;
          }
          
          EVLogger.debug('Folder details retrieved successfully', {
            'folderId': folderId,
            'folderName': folderItem.name,
            'step': 'folder_details_success',
          });
          
          // Get all children from the server
          final serverChildren = await browseService.getChildren(folderItem);
          serverChildrenMap[folderId] = serverChildren;
          
          EVLogger.debug('Got server children for folder', {
            'folderId': folderId,
            'serverChildrenCount': serverChildren.length,
            'step': 'got_server_children',
          });
          
        } catch (e) {
          EVLogger.error('Error checking folder for deletion', {
            'folderId': folderId,
            'error': e.toString(),
            'step': 'folder_deletion_check_error',
          });
          
          // Only clean up if we get a specific 404 error AND we can verify the folder is deleted
          if (e.toString().contains('404')) {
            EVLogger.warning('Folder returned 404, verifying if truly deleted...', {
              'folderId': folderId,
              'error': e.toString(),
              'step': '404_error_verification',
            });
            
            // Verify if the folder is truly deleted before cleaning up
            final isDeleted = await _isFolderTrulyDeleted(folderId, browseService);
            EVLogger.debug('404 verification result', {
              'folderId': folderId,
              'isDeleted': isDeleted,
              'step': '404_verification_result',
            });
            
            if (isDeleted) {
              EVLogger.warning('Folder confirmed as deleted, cleaning up...', {
                'folderId': folderId,
                'step': '404_cleanup_confirmed',
              });
              await _cleanupDeletedFolder(folderId);
            } else {
              EVLogger.warning('Folder returned 404 but may still exist - not cleaning up', {
                'folderId': folderId,
                'step': '404_no_cleanup',
              });
            }
          }
          // Continue with other folders
        }
      }
      
      // Now check for new folders in each accessible folder
      for (final entry in serverChildrenMap.entries) {
        final folderId = entry.key;
        final serverChildren = entry.value;
        
        // Get existing offline children for this folder
        final existingOfflineChildren = allItems
            .where((item) => item['parent_id'] == folderId)
            .map((item) => item['id'])
            .toSet();
        
        // Find new folders that aren't offline yet
        final newFolders = serverChildren
            .where((child) => 
                (child.type == 'folder' || child.isDepartment) && 
                !existingOfflineChildren.contains(child.id))
            .toList();
        
        EVLogger.debug('Found new folders', {
          'folderId': folderId,
          'newFoldersCount': newFolders.length,
          'newFolderNames': newFolders.map((f) => f.name).toList(),
          'step': 'found_new_folders',
        });
        
        if (newFolders.isNotEmpty) {
          _notifyProgress('Found ${newFolders.length} new folders, downloading...');
          
          // Download each new folder
          for (final newFolder in newFolders) {
            try {
              EVLogger.debug('Downloading new folder', {
                'folderId': newFolder.id,
                'folderName': newFolder.name,
                'parentId': folderId,
                'step': 'download_new_folder',
              });
              
              await _downloadNewFolder(newFolder, folderId);
              _notifyProgress('Downloaded new folder: ${newFolder.name}');
              
              EVLogger.debug('Successfully downloaded new folder', {
                'folderId': newFolder.id,
                'folderName': newFolder.name,
                'parentId': folderId,
                'step': 'download_success',
              });
            } catch (e) {
              EVLogger.error('Failed to download new folder', {
                'folderId': newFolder.id,
                'folderName': newFolder.name,
                'error': e.toString(),
                'step': 'download_failed',
              });
              // Continue with other folders
            }
          }
        }
      }
    } catch (e) {
      EVLogger.error('Error checking for new folders and deletions', {
        'error': e.toString(),
        'step': 'check_folders_error',
      });
    }
  }
  
  /// Download a new folder and its contents
  Future<void> _downloadNewFolder(BrowseItem folder, String parentId) async {
    try {
      EVLogger.debug('Starting download of new folder', {
        'folderId': folder.id,
        'folderName': folder.name,
        'parentId': parentId,
        'step': 'download_folder_start',
      });
      
      // Save folder metadata to database
      await _database.insertItem(
        folder,
        parentId: parentId,
        syncStatus: 'synced',
      );
      
      EVLogger.debug('Saved folder metadata to database', {
        'folderId': folder.id,
        'folderName': folder.name,
        'step': 'folder_metadata_saved',
      });
      
      // Download folder contents using offline manager
      final offlineManager = await OfflineManager.createDefault();
      await offlineManager.keepOffline(folder, parentId: parentId);
      
      EVLogger.debug('Successfully downloaded new folder and contents', {
        'folderId': folder.id,
        'folderName': folder.name,
        'step': 'download_folder_complete',
      });
    } catch (e) {
      EVLogger.error('Failed to download new folder', {
        'folderId': folder.id,
        'folderName': folder.name,
        'error': e.toString(),
        'step': 'download_folder_failed',
      });
      rethrow;
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