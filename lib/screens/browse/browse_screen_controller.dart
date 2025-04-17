import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/offline/offline_storage_provider.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Controller for the BrowseScreen
/// Separates business logic from UI
class BrowseScreenController extends ChangeNotifier {
  final String baseUrl;
  final String authToken; 
  final String instanceType;
  final AngoraBaseService? angoraBaseService;
  final BuildContext context;
  final GlobalKey<ScaffoldState> scaffoldKey;
  
  // State variables
  bool isLoading = true;
  List<BrowseItem> items = [];
  String? errorMessage;
  List<BrowseItem> navigationStack = [];
  BrowseItem? currentFolder;
  bool _isOffline = false;
  bool _disposed = false; // Add a flag to track if the controller has been disposed
  
  // Callback for state updates
  final Function()? onStateChanged;
  
  // Cancel token for network requests
  CancelToken? _cancelToken;
  
  // Add a debouncer for smoother UI updates
  final _debouncer = Debouncer<void>(
    Duration(milliseconds: 300),
    initialValue: null,
  );
  
  // Pagination properties
  int _currentPage = 0;
  final int _itemsPerPage = 25;
  bool _hasMoreItems = true;
  bool _isLoadingMore = false;
  
  final OfflineManager _offlineManager;
  final Set<String> _offlineItems = {};
  
  Timer? _debounceTimer;
  
  final Connectivity _connectivity = Connectivity();
  
  BrowseScreenController({
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    required this.onStateChanged,
    required this.context,
    required this.scaffoldKey,
    required OfflineManager offlineManager,
  }) : angoraBaseService = instanceType.toLowerCase() == 'angora' 
        ? AngoraBaseService(baseUrl)
        : null,
        _offlineManager = offlineManager {
    
    // Initialize Angora base service if needed
    if (angoraBaseService != null) {
      angoraBaseService!.setToken(authToken);
    }
    
    // Check initial connectivity
    _checkConnectivity();
    
    // Set up debouncer listener
    _debouncer.values.listen((_) {
      _notifyListeners();
    });
    
    _initConnectivityListener();
  }
  
  /// Helper method to safely notify listeners
  void _notifyListeners() {
    EVLogger.debug('_notifyListeners called', {'disposed': _disposed});
    if (_disposed) {
      EVLogger.debug('_notifyListeners skipped - controller is disposed');
      return; // Don't notify if disposed
    }
    
    if (onStateChanged != null) {
      EVLogger.debug('Calling onStateChanged callback');
      onStateChanged!();
      EVLogger.debug('onStateChanged callback completed');
    }
    
    EVLogger.debug('Calling notifyListeners');
    notifyListeners();
    EVLogger.debug('notifyListeners completed');
  }
  
  /// Debounced version of state change notification
  void notifyStateChanged() {
    if (_disposed) return; // Don't notify if disposed
    _debouncer.value = null; // Trigger the debouncer
  }
  
  /// Check initial connectivity state
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOffline = result == ConnectivityResult.none || result == ConnectivityResult.other;
      EVLogger.debug('Initial connectivity check', {
        'result': result.toString(),
        'isOffline': _isOffline
      });
    } catch (e) {
      EVLogger.error('Error checking connectivity', e);
      _isOffline = true; // Assume offline if we can't check
    }
  }

  /// Set offline mode
  void setOfflineMode(bool offline) {
    if (_isOffline != offline) {
      EVLogger.debug('Setting offline mode', {'offline': offline});
      _isOffline = offline;
      if (_isOffline) {
        _hasMoreItems = false; // No pagination in offline mode
      }
      notifyListeners();
    }
  }

  /// Load more items when scrolling to the end of the list
  Future<void> loadMoreItems() async {
    if (!_hasMoreItems || _isLoadingMore || currentFolder == null) return;
    
    _isLoadingMore = true;
    onStateChanged?.call();
    
    try {
      final nextPage = _currentPage + 1;
      final skipCount = nextPage * _itemsPerPage;
      
      // Get the browse service
      final browseService = BrowseServiceFactory.getService(
        instanceType, 
        baseUrl, 
        authToken
      );
      
      // Fetch more items with pagination parameters
      final moreItems = await browseService.getChildren(
        currentFolder!,
        skipCount: skipCount,
        maxItems: _itemsPerPage,
      );
      
      if (moreItems.isEmpty) {
        _hasMoreItems = false;
      } else {
        _currentPage = nextPage;
        // Add the new items to the existing list
        items.addAll(moreItems);
      }
    } catch (e) {
      EVLogger.error('Failed to load more items', e);
      errorMessage = 'Failed to load more items: ${e.toString()}';
    } finally {
      _isLoadingMore = false;
      onStateChanged?.call();
    }
  }

  void setLoading(bool loading) {
    isLoading = loading;
    onStateChanged?.call();
  }

  /// Loads folder contents with pagination reset
  Future<void> loadFolderContents(BrowseItem folder) async {
    if (isLoading == true) return;
    
    try {
      isLoading = true;
      _notifyListeners();
      
      // Cache offline status to avoid repeated checks
      final isOffline = _offlineManager.isOffline;
      
      if (isOffline == true) {
        final offlineItems = await _offlineManager.getOfflineItems(folder.id);
        items = offlineItems;
        currentFolder = folder;
        _notifyListeners();
        return;
      }
      
      final browseService = BrowseServiceFactory.getService(
        instanceType, 
        baseUrl, 
        authToken
      );

      final result = await browseService.getChildren(
        folder,
        skipCount: 0,
        maxItems: _itemsPerPage,
      );
      
      EVLogger.debug('Loaded items from service', {
        'count': result.length,
        'firstItemCanWrite': result.isNotEmpty ? result.first.canWrite : null,
        'firstItemAllowableOperations': result.isNotEmpty ? result.first.allowableOperations : null,
      });
      
      for (var item in result) {
        if (await isItemAvailableOffline(item.id)) {
          _offlineItems.add(item.id);
        }
      }
      
      items = result;
      currentFolder = folder;
      _notifyListeners();
    } catch (e) {
      EVLogger.error('Error loading folder contents', {
        'folderId': folder.id,
        'error': e.toString(),
      });
      
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        _isOffline = true;
        try {
          final offlineItems = await _offlineManager.getOfflineItems(folder.id);
          items = offlineItems;
          currentFolder = folder;
          _notifyListeners();
          if (onStateChanged != null) {
            ScaffoldMessenger.of(_getContext()).showSnackBar(
              const SnackBar(
                content: Text('You are offline. Showing available offline content.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (offlineError) {
          errorMessage = 'Failed to load offline content: ${offlineError.toString()}';
          currentFolder = folder;
          _notifyListeners();
        }
      } else if (e is! DioException || (e is DioException && e.type != DioExceptionType.cancel)) {
        errorMessage = 'Failed to load contents: ${e.toString()}';
        currentFolder = folder;
        _notifyListeners();
      }
    } finally {
      isLoading = false;
      _notifyListeners();
    }
  }

  // Add getters for pagination state
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreItems => _hasMoreItems;

  /// Loads top-level departments/folders
  Future<void> loadDepartments() async {
    EVLogger.debug('Starting loadDepartments');
    isLoading = true;
    errorMessage = null;
    _currentPage = 0;
    _hasMoreItems = !_isOffline;
    _notifyListeners();
    EVLogger.debug('Initial state set in loadDepartments');

    try {
      _isOffline = await _offlineManager.isOffline();
      EVLogger.debug('Offline status checked', {'isOffline': _isOffline});
      
      if (_isOffline) {
        EVLogger.debug('Loading offline items for departments');
        final offlineItems = await _offlineManager.getOfflineItems(null);
        EVLogger.debug('Retrieved offline items', {'count': offlineItems.length});
        items = offlineItems;
        _hasMoreItems = false;
      } else {
        EVLogger.debug('Loading online departments');
        final browseService = BrowseServiceFactory.getService(
          instanceType, 
          baseUrl, 
          authToken
        );
        EVLogger.debug('Browse service created');

        final rootItem = BrowseItem(
          id: 'root',
          name: 'Root',
          type: 'folder',
          isDepartment: instanceType == 'Angora',
        );
        EVLogger.debug('Root item created', {'id': rootItem.id, 'isDepartment': rootItem.isDepartment});

        EVLogger.debug('Calling getChildren on browse service');
        final loadedItems = await browseService.getChildren(
          rootItem,
          skipCount: 0,
          maxItems: _itemsPerPage,
        );
        
        EVLogger.debug('Retrieved sites', {'count': loadedItems.length});
        
        EVLogger.debug('Setting items and updating UI');
        items = loadedItems;
        if (loadedItems.length < _itemsPerPage) {
          _hasMoreItems = false;
        }
        EVLogger.debug('Items set and UI updated');
      }
    } catch (e) {
      EVLogger.error('Error loading departments', e);
      errorMessage = 'Failed to load departments: ${e.toString()}';
    } finally {
      EVLogger.debug('Finishing loadDepartments');
      isLoading = false;
      _notifyListeners();
      EVLogger.debug('loadDepartments completed');
      EVLogger.debug('loadDepartments completed, isLoading set to ''$isLoading');

    }
  }

  Future<String> _fetchDocumentLibraryId(String siteId) async {
    // Only call this method for Alfresco/Classic repositories
    if (instanceType.toLowerCase() == 'angora') {
      return siteId; // For Angora, just return the site ID itself
    }
    
    final response = await http.get(
      Uri.parse('$baseUrl/api/-default-/public/alfresco/versions/1/sites/$siteId/containers'),
      headers: {'Authorization': authToken},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      for (var entry in data['list']['entries']) {
        if (entry['entry']['folderId'] == 'documentLibrary') {
          return entry['entry']['id'];
        }
      }
    }

    throw Exception('Document library not found for site $siteId');
  }
  
  /// Navigates to a specific folder and loads its contents
  Future<void> navigateToFolder(BrowseItem folder) async {
    isLoading = true;
    errorMessage = null;
    _notifyListeners();

    try {
      if (_isOffline) {
        // In offline mode, just load offline contents
        final offlineItems = await _offlineManager.getOfflineItems(folder.id);
        items = offlineItems;
        
        // Update navigation stack
        if (currentFolder?.id == 'root') {
          navigationStack = [];
        } else if (currentFolder != null) {
          navigationStack.add(currentFolder!);
        }
        
        currentFolder = folder;
        isLoading = false;
        _notifyListeners();
        return;
      }

      await loadFolderContents(folder);
      
      // If navigating from root, start a new navigation stack
      if (currentFolder?.id == 'root') {
        navigationStack = [];
      } 
      // Otherwise add current folder to navigation stack
      else if (currentFolder != null) {
        navigationStack.add(currentFolder!);
      }
      
      currentFolder = folder;
      _notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to load folder contents: ${e.toString()}';
      isLoading = false;
      _notifyListeners();
    }
  }
  
  /// Navigates to a specific point in breadcrumb
  void navigateToBreadcrumb(int index) {    
    final targetFolder = navigationStack[index];
    final newStack = navigationStack.sublist(0, index);
    
    navigationStack = newStack;
    currentFolder = targetFolder;
    _notifyListeners();
    
    loadFolderContents(targetFolder);
  }

  /// Properly clean up resources when controller is no longer needed
  @override
  void dispose() {
    _disposed = true; // Mark as disposed
    // Cancel any ongoing network requests
    _cancelToken?.cancel("Controller disposed");
    
    // No need to dispose debouncer in newer versions of the package
    // If using an older version that requires disposal, uncomment:
    // _debouncer.dispose();
    
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Add this method to ensure permissions are loaded
  Future<void> _loadItemPermissions(List<BrowseItem> items) async {
    // This would be implemented if needed, but for now we're relying on
    // the allowableOperations that should be returned with each item
    // from the API
  }

  // Add this method to check if an item is available offline
  Future<bool> isItemAvailableOffline(String itemId) async {
    if (_offlineItems.contains(itemId)) {
      return true;
    }
    final isAvailable = await _offlineManager.isAvailableOffline(itemId);
    if (isAvailable) {
      _offlineItems.add(itemId);
    }
    return isAvailable;
  }

  // Add this method to toggle offline availability
  Future<void> toggleOfflineAvailability(BrowseItem item) async {
    try {
      final isAvailable = await isItemAvailableOffline(item.id);
      
      if (isAvailable) {
        // Remove from offline
        await _offlineManager.removeOffline(item.id);
        _offlineItems.remove(item.id);
      } else {
        // Add to offline
        await _offlineManager.keepOffline(item);
        _offlineItems.add(item.id);
      }
      
      // Notify listeners of the change
      onStateChanged?.call();
    } catch (e) {
      EVLogger.error('Error toggling offline availability', e);
      rethrow;
    }
  }

  // Add this helper method to get context
  BuildContext _getContext() {
    return scaffoldKey.currentContext ?? context;
  }

  void _initConnectivityListener() {
    _offlineManager.onConnectivityChanged.listen((result) {
      // Consider both ConnectivityResult.none and ConnectivityResult.other as offline states
      final isOffline = result == ConnectivityResult.none || result == ConnectivityResult.other;
      
      // Debounce connectivity changes to prevent rapid state updates
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 2), () async {
        if (isOffline != _isOffline) {
          EVLogger.debug('Connectivity changed', {
            'wasOffline': _isOffline,
            'isNowOffline': isOffline
          });
          
          _isOffline = isOffline;
          notifyListeners();
          
          // If we're offline, load offline content
          if (_isOffline) {
            await _loadOfflineContent();
          }
        }
      });
    });
    
    // Initial check
    _checkOfflineState();
  }
  
  Future<void> _checkOfflineState() async {
    final result = await _connectivity.checkConnectivity();
    _isOffline = result == ConnectivityResult.none || result == ConnectivityResult.other;
    EVLogger.debug('Checking offline state', {'isOffline': _isOffline});
    notifyListeners();
    
    if (_isOffline) {
      await _loadOfflineContent();
    }
  }

  Future<void> _loadOfflineContent() async {
    // Implementation of _loadOfflineContent method
  }
}
