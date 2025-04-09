import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


/// Controller for the BrowseScreen
/// Separates business logic from UI
class BrowseScreenController {
  final String baseUrl;
  final String authToken; 
  final String instanceType;
  final AngoraBaseService? angoraBaseService;
  
  // State variables
  bool isLoading = true;
  List<BrowseItem> items = [];
  String? errorMessage;
  List<BrowseItem> navigationStack = [];
  BrowseItem? currentFolder;
  
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
  
  final OfflineManager _offlineManager = OfflineManager();
  final Set<String> _offlineItems = {};
  
  /// Constructor initializes the controller with required parameters
  BrowseScreenController({
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    required this.onStateChanged,
  }) : angoraBaseService = instanceType.toLowerCase() == 'angora' 
        ? AngoraBaseService(baseUrl)
        : null {
    
    // Initialize Angora base service if needed
    if (angoraBaseService != null) {
      angoraBaseService!.setToken(authToken);
    }
    
    // Load departments initially
    loadDepartments();
    
    // Set up debouncer listener
    _debouncer.values.listen((_) {
      _notifyListeners();
    });
  }
  
  /// Helper method to safely notify listeners
  void _notifyListeners() {
    if (onStateChanged != null) {
      onStateChanged!();
    }
  }
  
  /// Debounced version of state change notification
  void notifyStateChanged() {
    _debouncer.value = null; // Trigger the debouncer
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
    // Cancel any ongoing request
    _cancelToken?.cancel("New request started");
    _cancelToken = CancelToken();

    currentFolder = folder;
    setLoading(true);
    errorMessage = null;
    _currentPage = 0;
    _hasMoreItems = true;
    items.clear();
    onStateChanged?.call();
    
    try {
      final browseService = BrowseServiceFactory.getService(
        instanceType, 
        baseUrl, 
        authToken
      );

      // Fetch initial items with pagination parameters
      final loadedItems = await browseService.getChildren(
        folder,
        skipCount: 0,
        maxItems: _itemsPerPage,
      );
      
      // Check offline status for each item
      for (var item in loadedItems) {
        if (await isItemAvailableOffline(item.id)) {
          _offlineItems.add(item.id);
        }
      }
      
      items = loadedItems;
      
      // If we got fewer items than requested, there are no more
      if (loadedItems.length < _itemsPerPage) {
        _hasMoreItems = false;
      }
      
      setLoading(false);
    } catch (e) {
      // Don't report errors from cancelled requests
      if (e is! DioException || (e is DioException && e.type != DioExceptionType.cancel)) {
        errorMessage = 'Failed to load contents: ${e.toString()}';
        setLoading(false);
        // Re-throw to be caught by the calling method
        rethrow;
      }
    }
  }

  // Add getters for pagination state
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreItems => _hasMoreItems;

  /// Loads top-level departments/folders
  Future<void> loadDepartments() async {
    isLoading = true;
    errorMessage = null;
    _currentPage = 0;
    _hasMoreItems = true;
    _notifyListeners();

    try {
      final browseService = BrowseServiceFactory.getService(
        instanceType, 
        baseUrl, 
        authToken
      );

      // Create a root BrowseItem to fetch top-level departments/sites
      final rootItem = BrowseItem(
        id: 'root',
        name: 'Root',
        type: 'folder',
        isDepartment: instanceType == 'Angora',
      );

      final loadedItems = await browseService.getChildren(
        rootItem,
        skipCount: 0,
        maxItems: _itemsPerPage,
      );
    
      items = [];
      for (var department in loadedItems) {
        // Different handling based on repository type
        if (instanceType.toLowerCase() == 'angora') {
          // For Angora, no document library concept - the department ID is the folder ID
          // We just need to add the department as is
          BrowseItem item = BrowseItem(
            id: department.id,
            name: department.name,
            type: 'folder',
            isDepartment: true,
            // For Angora, we use the department ID as the document library ID
            documentLibraryId: department.id,
            // In Angora, we assume write permissions unless explicitly denied
            allowableOperations: ['create', 'update', 'delete'],
          );
          
          items.add(item);
        } else {
          // Existing Alfresco/Classic logic
          try {
            final docLibId = await _fetchDocumentLibraryId(department.id);
            
            // For Alfresco/Classic, check permissions on the documentLibrary node
            List<String> siteOperations = [];
            
            try {
              // Try directly checking permissions on the documentLibrary node
              final nodeResponse = await http.get(
                Uri.parse('$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$docLibId?include=allowableOperations'),
                headers: {'Authorization': authToken},
              );
              
              if (nodeResponse.statusCode == 200) {
                final nodeData = json.decode(nodeResponse.body);
                
                // Check if allowableOperations exists and print its exact type
                if (nodeData['entry'].containsKey('allowableOperations')) {
                  final operations = nodeData['entry']['allowableOperations'];
                  
                  // Be extra careful with type conversion
                  List<String> ops = [];
                  if (operations is List) {
                    // Convert each element to string explicitly
                    for (var op in operations) {
                      ops.add(op.toString());
                    }
                    
                    siteOperations = ops;
                  }
                }
              } else {
                EVLogger.error('Failed to get node details', {
                  'status': nodeResponse.statusCode
                });
              }
            } catch (e) {
              EVLogger.error('Error checking node permissions', {'error': e.toString()});
              siteOperations = ['create']; // Fallback permissions
            }

            // Create BrowseItem with the operations we determined
            BrowseItem item = BrowseItem(
              id: department.id,
              name: department.name,
              type: 'folder',
              isDepartment: true,
              documentLibraryId: docLibId,
              allowableOperations: siteOperations,
            );
            
            items.add(item);
          } catch (e) {
            EVLogger.error('Error fetching document library', {
              'siteId': department.id,
              'error': e.toString()
            });
            // Skip this department if we can't find its document library
            continue;
          }
        }
      }
      
      // If we got fewer items than requested, there are no more
      if (loadedItems.length < _itemsPerPage) {
        _hasMoreItems = false;
      }
      
      isLoading = false;
      currentFolder = rootItem;
      navigationStack = [];
      _notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to load departments: ${e.toString()}';
      isLoading = false;
      _notifyListeners();
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
  void dispose() {
    // Cancel any ongoing network requests
    _cancelToken?.cancel("Controller disposed");
    
    // No need to dispose debouncer in newer versions of the package
    // If using an older version that requires disposal, uncomment:
    // _debouncer.dispose();
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
        final success = await _offlineManager.keepOffline(
          item: item,
          instanceType: instanceType,
          baseUrl: baseUrl,
          authToken: authToken,
        );
        
        if (success) {
          _offlineItems.add(item.id);
        }
      }
      
      // Notify listeners of the change
      onStateChanged?.call();
    } catch (e) {
      EVLogger.error('Error toggling offline availability', e);
      rethrow;
    }
  }
}
