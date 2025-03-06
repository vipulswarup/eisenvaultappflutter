import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

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
  final Function() onStateChanged;
  
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
  }
  
  /// Loads top-level departments/folders
  Future<void> loadDepartments() async {
    isLoading = true;
    errorMessage = null;
    onStateChanged();

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
      
      items = loadedItems;
      isLoading = false;
      currentFolder = rootItem;
      navigationStack = [];
      onStateChanged();
    } catch (e) {
      errorMessage = 'Failed to load departments: ${e.toString()}';
      isLoading = false;
      onStateChanged();
    }
  }
  
  /// Navigates to a specific folder and loads its contents
  Future<void> navigateToFolder(BrowseItem folder) async {
    EVLogger.debug('Navigating to folder', {'id': folder.id, 'name': folder.name});
    
    isLoading = true;
    errorMessage = null;
    onStateChanged();

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
      onStateChanged();
    } catch (e) {
      errorMessage = 'Failed to load folder contents: ${e.toString()}';
      isLoading = false;
      onStateChanged();
    }
  }
  
  /// Loads the contents of a specific folder
  Future<void> loadFolderContents(BrowseItem folder) async {
    try {
      final browseService = BrowseServiceFactory.getService(
        instanceType, 
        baseUrl, 
        authToken
      );

      final loadedItems = await browseService.getChildren(folder);
      
      items = loadedItems;
      isLoading = false;
      onStateChanged();
    } catch (e) {
      errorMessage = 'Failed to load contents: ${e.toString()}';
      isLoading = false;
      onStateChanged();
      
      // Re-throw to be caught by the calling method
      rethrow;
    }
  }
  
  /// Navigates to a specific point in breadcrumb
  void navigateToBreadcrumb(int index) {
    final targetFolder = navigationStack[index];
    final newStack = navigationStack.sublist(0, index);
    
    navigationStack = newStack;
    currentFolder = targetFolder;
    onStateChanged();
    
    loadFolderContents(targetFolder);
  }
}
