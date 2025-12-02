import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      // Set up token refresh callback for Angora
      if (instanceType.toLowerCase() == 'angora') {
        angoraBaseService!.setTokenRefreshCallback(_createTokenRefreshCallback());
      }
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
    
    if (_disposed) {
      
      return; // Don't notify if disposed
    }
    
    if (onStateChanged != null) {
      
      onStateChanged!();
      
    }
    
    
    notifyListeners();
    
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
      // Only consider ConnectivityResult.none as offline
      // ConnectivityResult.other can be VPN connections and should not be treated as offline
      _isOffline = result == ConnectivityResult.none;
      _notifyListeners();
    } catch (e) {
      EVLogger.error('Error checking connectivity', e);
    }
  }
  
  /// Creates a token refresh callback for Angora services
  /// This callback will be called when a 401 is detected, and it will update
  /// the token in AuthStateManager and return the new token so the service instance
  /// can update its own token
  Future<String?> Function() _createTokenRefreshCallback() {
    return () async {
      try {
        final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
        EVLogger.info('Token refresh callback invoked');
        final refreshed = await authStateManager.refreshToken();
        if (refreshed) {
          final newToken = authStateManager.currentToken;
          if (newToken != null) {
            // Update token in the controller's base service
            if (angoraBaseService != null) {
              angoraBaseService!.setToken(newToken);
              EVLogger.info('Token updated in BrowseScreenController angoraBaseService');
            }
            EVLogger.info('Token refresh completed successfully, new token length: ${newToken.length}');
            return newToken;
          } else {
            EVLogger.warning('Token refresh succeeded but new token is null');
            return null;
          }
        } else {
          EVLogger.warning('Token refresh failed');
          return null;
        }
      } catch (e) {
        EVLogger.error('Error in token refresh callback', e);
        return null;
      }
    };
  }
  
  /// Helper method to get browse service with token refresh callback
  /// Gets the latest token from AuthStateManager to ensure we use refreshed tokens
  BrowseService _getBrowseService() {
    // Get the latest token from AuthStateManager in case it was refreshed
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final currentToken = authStateManager.currentToken ?? authToken;
    
    return BrowseServiceFactory.getService(
      instanceType,
      baseUrl,
      currentToken,
      tokenRefreshCallback: instanceType.toLowerCase() == 'angora' 
        ? _createTokenRefreshCallback()
        : null,
    );
  }

  /// Set offline mode
  void setOfflineMode(bool offline) {
    if (_isOffline != offline) {
      
      _isOffline = offline;
      if (_isOffline) {
        _hasMoreItems = false; // No pagination in offline mode
      }
      notifyListeners();
    }
  }

  /// Load more items when scrolling to the end of the list
  Future<void> loadMoreItems() async {
    if (currentFolder == null) {
      await loadMoreDepartments();
    } else {
      await _loadMoreFolderItems();
    }
  }

  Future<void> _loadMoreFolderItems() async {
    if (!_hasMoreItems || _isLoadingMore || currentFolder == null) return;
    _isLoadingMore = true;
    onStateChanged?.call();
    try {
      final nextPage = _currentPage + 1;
      final skipCount = nextPage * _itemsPerPage;
      final browseService = _getBrowseService();
      final moreItems = await browseService.getChildren(
        currentFolder!,
        skipCount: skipCount,
        maxItems: _itemsPerPage,
      );
      if (moreItems.isEmpty) {
        _hasMoreItems = false;
      } else {
        _currentPage = nextPage;
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

  /// Loads folder contents without changing navigation
  Future<void> loadFolderContents(BrowseItem folder) async {
    if (isLoading) return;
    
    try {
      isLoading = true;
      errorMessage = null;
      _notifyListeners();
      
      // Set current folder
      currentFolder = folder;
      
      // Check both actual connectivity and forced offline mode
      _isOffline =  await _offlineManager.isOffline();
      
      // Load folder contents
      if (_isOffline) {
        final offlineItems = await _offlineManager.getOfflineItems(folder.id);
        items = offlineItems;
        _hasMoreItems = false;
      } else {
        final browseService = _getBrowseService();
        
        final result = await browseService.getChildren(
          folder,
          skipCount: 0,
          maxItems: _itemsPerPage,
        );
        
        items = result;
        _hasMoreItems = result.length >= _itemsPerPage;
      }
      
      // Reset pagination
      _currentPage = 0;
      
    } catch (e) {
      EVLogger.error('FOLDER NAVIGATION: Error loading folder contents', {
        'error': e.toString(),
      });
      errorMessage = 'Failed to load folder contents: ${e.toString()}';
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
    EVLogger.productionLog('=== LOAD DEPARTMENTS START ===');
    EVLogger.productionLog('Instance Type: $instanceType');
    EVLogger.productionLog('Base URL: $baseUrl');
    EVLogger.productionLog('Auth Token: ${authToken.isNotEmpty ? "Present (${authToken.length} chars)" : "EMPTY"}');
    
    isLoading = true;
    errorMessage = null;
    _currentPage = 0;
    _hasMoreItems = !_isOffline;
    
    // Clear navigation stack and current folder when going to home
    navigationStack.clear();
    currentFolder = null;
    items = [];
    
    _notifyListeners();

    try {
      // Check both actual connectivity and forced offline mode
      _isOffline = await _offlineManager.isOffline();
      EVLogger.productionLog('Offline mode: $_isOffline');
      
      if (_isOffline) {
        EVLogger.productionLog('Loading offline items...');
        final offlineItems = await _offlineManager.getOfflineItems(null);
        items = offlineItems;
        _hasMoreItems = false;
        EVLogger.productionLog('Loaded ${offlineItems.length} offline items');
      } else {
        EVLogger.productionLog('Creating browse service...');
        final browseService = _getBrowseService();
        EVLogger.productionLog('Browse service created successfully');

        final rootItem = BrowseItem(
          id: 'root',
          name: 'Root',
          type: 'folder',
          isDepartment: instanceType == 'Angora',
        );
        EVLogger.productionLog('Root item created: ${rootItem.id}');

        EVLogger.productionLog('Calling getChildren on browse service...');
        final loadedItems = await browseService.getChildren(
          rootItem,
          skipCount: 0,
          maxItems: _itemsPerPage,
        );
        EVLogger.productionLog('Successfully loaded ${loadedItems.length} items');
        items = loadedItems;
        _hasMoreItems = loadedItems.length >= _itemsPerPage;
      }
    } catch (e) {
      EVLogger.error('Error loading departments', e);
      EVLogger.productionLog('Error type: ${e.runtimeType}');
      EVLogger.productionLog('Error message: ${e.toString()}');
      errorMessage = 'Failed to load departments: ${e.toString()}';
    } finally {
      isLoading = false;
      _notifyListeners();
      EVLogger.productionLog('=== LOAD DEPARTMENTS END ===');
    }
  }

  /// Loads more departments/sites for pagination
  Future<void> loadMoreDepartments() async {
    if (!_hasMoreItems || isLoading || currentFolder != null) return;
    isLoading = true;
    _notifyListeners();
    try {
      final browseService = _getBrowseService();
      final rootItem = BrowseItem(
        id: 'root',
        name: 'Root',
        type: 'folder',
        isDepartment: instanceType == 'Angora',
      );
      final nextPage = _currentPage + 1;
      final skipCount = nextPage * _itemsPerPage;
      final loadedItems = await browseService.getChildren(
        rootItem,
        skipCount: skipCount,
        maxItems: _itemsPerPage,
      );
      items.addAll(loadedItems);
      if (loadedItems.length < _itemsPerPage) {
        _hasMoreItems = false;
      } else {
        _currentPage = nextPage;
      }
    } catch (e) {
      EVLogger.error('Error loading more departments', e);
      errorMessage = 'Failed to load more departments: ${e.toString()}';
    } finally {
      isLoading = false;
      _notifyListeners();
    }
  }

  
  /// Navigates to a specific folder and loads its contents
  Future<void> navigateToFolder(BrowseItem folder) async {
    EVLogger.productionLog('=== NAVIGATE TO FOLDER START ===');
    EVLogger.productionLog('Folder ID: ${folder.id}');
    EVLogger.productionLog('Folder Name: ${folder.name}');
    EVLogger.productionLog('Is Department: ${folder.isDepartment}');
    EVLogger.productionLog('Current isLoading: $isLoading');
    
    // Don't navigate if we're already loading (unless it's been loading for too long)
    if (isLoading) {
      EVLogger.productionLog('Controller is already loading, waiting...');
      // Wait a bit and try again if still loading
      await Future.delayed(const Duration(milliseconds: 500));
      if (isLoading) {
        EVLogger.productionLog('Still loading after wait, proceeding anyway');
        // Reset loading state and proceed
        isLoading = false;
      }
    }
    
    try {
      isLoading = true;
      errorMessage = null;
      _notifyListeners();
      
      // Check both actual connectivity and forced offline mode
      _isOffline =  await _offlineManager.isOffline();
      EVLogger.productionLog('Offline mode: $_isOffline');
      
      // No special handling for departments/sites; just load their children
      if (_isOffline) {
        EVLogger.productionLog('Loading offline items for folder: ${folder.id}');
        final offlineItems = await _offlineManager.getOfflineItems(folder.id);
        items = offlineItems;
        _hasMoreItems = false;
        EVLogger.productionLog('Loaded ${offlineItems.length} offline items');
      } else {
        EVLogger.productionLog('Creating browse service...');
        final browseService = _getBrowseService();
        EVLogger.productionLog('Browse service created, calling getChildren...');
        
        final result = await browseService.getChildren(
          folder,
          skipCount: 0,
          maxItems: _itemsPerPage,
        );
        
        EVLogger.productionLog('Successfully loaded ${result.length} items');
        items = result;
        _hasMoreItems = result.length >= _itemsPerPage;
      }
      
      // Update navigation stack after loading contents
      if (currentFolder != null && currentFolder!.id != 'root') {
        navigationStack.add(currentFolder!);
      } else if (currentFolder?.id == 'root') {
        // Clear navigation stack when coming from root
        navigationStack.clear();
      }
      
      // Set current folder
      currentFolder = folder;
      
      // Reset pagination
      _currentPage = 0;
      
    } catch (e) {
      EVLogger.error('FOLDER NAVIGATION: Error navigating to folder', {
        'error': e.toString(),
        'folderId': folder.id,
        'folderName': folder.name,
      });
      errorMessage = 'Failed to load folder contents: ${e.toString()}';
    } finally {
      // Always reset loading state
      isLoading = false;
      EVLogger.productionLog('=== NAVIGATE TO FOLDER END ===');
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


  // Add this method to check if an item is available offline
  Future<bool> isItemAvailableOffline(String itemId) async {
    if (_offlineItems.contains(itemId)) {
      return true;
    }
    final isAvailable = await _offlineManager.isItemOffline(itemId);
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


  void _initConnectivityListener() {
    _offlineManager.onConnectivityChanged.listen((result) {
      // Only consider ConnectivityResult.none as offline
      // ConnectivityResult.other can be VPN connections and should not be treated as offline
      final isOffline = result == ConnectivityResult.none;
      
      // Debounce connectivity changes to prevent rapid state updates
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 2), () async {
        if (isOffline != _isOffline) {
          
          
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
    // Only consider ConnectivityResult.none as offline
    // ConnectivityResult.other can be VPN connections and should not be treated as offline
    _isOffline = result == ConnectivityResult.none;
    
    notifyListeners();
    
    if (_isOffline) {
      await _loadOfflineContent();
    }
  }

  Future<void> _loadOfflineContent() async {
    // Implementation of _loadOfflineContent method
  }

  /// Handles back navigation
  /// Returns true if back navigation was handled, false otherwise
  bool handleBackNavigation() {
    
    
    // If we have a navigation stack, go back
    if (navigationStack.isNotEmpty) {
      final previousFolder = navigationStack.removeLast();
      
      
      // Load the previous folder's contents
      loadFolderContents(previousFolder);
      return true;
    }
    
    // If we're not at the root level, go to root
    if (currentFolder != null && currentFolder!.id != 'root') {
      
      loadDepartments();
      return true;
    }
    
    
    return false;
  }
}
