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
  
  /// Loads top-level departments/folders
  Future<void> loadDepartments() async {
    isLoading = true;
    errorMessage = null;
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

      final loadedItems = await browseService.getChildren(rootItem);
    
      items = [];
      for (var department in loadedItems) {
        final docLibId = await _fetchDocumentLibraryId(department.id);
      
        items.add(
          BrowseItem(
            id: department.id,
            name: department.name,
            type: 'folder',
            isDepartment: true,
            documentLibraryId: docLibId,
          )
        );
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

    try {
      final browseService = BrowseServiceFactory.getService(
        instanceType, 
        baseUrl, 
        authToken
      );

      // Remove the cancelToken parameter if not supported by the service
      final loadedItems = await browseService.getChildren(folder);
    
      items = loadedItems;
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
