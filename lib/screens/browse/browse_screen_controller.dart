import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
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
  
  /// Constructor initializes the controller with required parameters
  BrowseScreenController({
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    required this.onStateChanged,
  }) : angoraBaseService = instanceType == 'Angora' 
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

  /// Load more items when scrolling to the bottom of the list
  Future<void> loadMoreItems() async {
    // Don't load more if already loading, no more items, or no current folder
    if (!_hasMoreItems || _isLoadingMore || currentFolder == null) return;
    
    _isLoadingMore = true;
    onStateChanged?.call();
    
    try {
      // Calculate skip count for pagination
      final nextPage = _currentPage + 1;
      final skipCount = nextPage * _itemsPerPage;
      
      // Get browse service for the current instance type
      final browseService = BrowseServiceFactory.getService(
        instanceType, 
        baseUrl, 
        authToken
      );
      
      // Load the next page of items
      final moreItems = await browseService.getChildren(
        currentFolder!,
        skipCount: skipCount,
        maxItems: _itemsPerPage,
      );
      
      // If we got fewer items than requested, there are no more
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

  // Getters for pagination state
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreItems => _hasMoreItems;

  /// Loads top-level departments/folders
  Future<void> loadDepartments() async {
    isLoading = true;
    errorMessage = null;
    
    // Reset pagination state
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

      // Load first page of departments
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
          
          EVLogger.debug('Angora Department Added', {
            'id': item.id,
            'name': item.name,
            'documentLibraryId': item.documentLibraryId,
            'allowableOperations': item.allowableOperations
          });
          
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
              
              EVLogger.debug('Document library node response', {
                'statusCode': nodeResponse.statusCode,
                'docLibId': docLibId,
                'response': nodeResponse.body
              });
              if (nodeResponse.statusCode == 200) {
                final nodeData = json.decode(nodeResponse.body);
                
                EVLogger.debug('Document library node response structure', {
                  'hasEntry': nodeData.containsKey('entry'),
                  'entryKeys': nodeData['entry']?.keys.toList() ?? []
                });
                
                // Check if allowableOperations exists and print its exact type
                if (nodeData['entry'].containsKey('allowableOperations')) {
                  final operations = nodeData['entry']['allowableOperations'];
                  
                  EVLogger.debug('Operations data details', {
                    'type': operations.runtimeType.toString(),
                    'isNull': operations == null,
                    'value': operations
                  });
                  
                  // Be extra careful with type conversion
                  List<String> ops = [];
                  if (operations is List) {
                    // Convert each element to string explicitly
                    for (var op in operations) {
                      ops.add(op.toString());
                    }
                    
                    EVLogger.debug('Converted operations', {
                      'operations': ops,
                      'count': ops.length
                    });
                    
                    siteOperations = ops;
                  } else {
                    EVLogger.error('Operations is not a list', {
                      'operations': operations
                    });
                  }
                } else {
                  EVLogger.debug('No allowableOperations found in response', {
                    'availableKeys': nodeData['entry'].keys.toList()
                  });
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
      
      // Check if we have fewer items than requested (no more to load)
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

  /// Helper method to fetch document library ID for a site (Alfresco/Classic only)
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
    EVLogger.debug('Navigating to folder', {'id': folder.id, 'name': folder.name});
    
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
  
  /// Loads the contents of a specific folder
  /// Uses cancellation token to prevent multiple concurrent requests
  Future<void> loadFolderContents(BrowseItem folder) async {
    // Cancel any ongoing request
    _cancelToken?.cancel("New request started");
    _cancelToken = CancelToken();

    // Reset pagination state
    _currentPage = 0;
    _hasMoreItems = true;

    try {
      final browseService = BrowseServiceFactory.getService(
        instanceType, 
        baseUrl, 
        authToken
      );

      // Load first page of folder contents with pagination
      final loadedItems = await browseService.getChildren(
        folder,
        skipCount: 0,
        maxItems: _itemsPerPage,
      );
    
      // Log permissions for debugging
      if (folder.allowableOperations != null) {
        EVLogger.debug('Folder permissions', {
          'folder': folder.name,
          'operations': folder.allowableOperations,
          'canWrite': folder.canWrite
        });
      }
    
      items = loadedItems;
      
      // If we got fewer items than requested, there are no more
      if (loadedItems.length < _itemsPerPage) {
        _hasMoreItems = false;
      }
      
      isLoading = false;
      _notifyListeners();
    } catch (e) {
      // Don't report errors from cancelled requests
      if (e is! DioException || (e is DioException && e.type != DioExceptionType.cancel)) {
        errorMessage = 'Failed to load contents: ${e.toString()}';
        isLoading = false;
        _notifyListeners();
      
        // Re-throw to be caught by the calling method
        rethrow;
      }
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
}
