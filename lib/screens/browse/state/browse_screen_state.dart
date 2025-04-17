import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

/// State management class for the Browse Screen
/// Handles the UI state and coordinates with the controller
class BrowseScreenState extends ChangeNotifier {
  // Controller reference
  BrowseScreenController? controller;
  
  // Selection mode state
  bool _isInSelectionMode = false;
  final Set<String> _selectedItems = {};
  
  // Offline state
  bool _isOffline = false;
  
  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  
  // Constructor that properly initializes the controller
  BrowseScreenState({
    required BuildContext context,
    required String baseUrl,
    required String authToken,
    required String instanceType,
    required GlobalKey<ScaffoldState> scaffoldKey,
  }) {
    // Initialize the OfflineManager first
    _initializeController(context, baseUrl, authToken, instanceType, scaffoldKey);
  }
  
  Future<void> _initializeController(
    BuildContext context,
    String baseUrl,
    String authToken,
    String instanceType,
    GlobalKey<ScaffoldState> scaffoldKey,
  ) async {
    try {
      final offlineManager = await OfflineManager.createDefault();
      
      // Create the controller with the OfflineManager
      controller = BrowseScreenController(
        baseUrl: baseUrl,
        authToken: authToken,
        instanceType: instanceType,
        onStateChanged: () {
          notifyListeners();
        },
        context: context,
        scaffoldKey: scaffoldKey,
        offlineManager: offlineManager,
      );
      
      // Initialize connectivity monitoring
      _initConnectivityMonitoring();
      
      // Check initial connectivity
      await _checkConnectivity();
      
      // Notify listeners that controller is ready
      notifyListeners();
      
      EVLogger.debug('BrowseScreenState initialized', {
        'baseUrl': baseUrl,
        'instanceType': instanceType,
      });
    } catch (e) {
      EVLogger.error('Error initializing BrowseScreenState', e);
    }
  }
  
  /// Initialize connectivity monitoring
  void _initConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  /// Check initial connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      EVLogger.error('Error checking connectivity', e);
      // If we can't check connectivity, assume we're offline
      _updateConnectionStatus(ConnectivityResult.none);
    }
  }
  
  /// Update connection status
  void _updateConnectionStatus(ConnectivityResult result) {
    // Consider both ConnectivityResult.none and ConnectivityResult.other as offline states
    final isNowOffline = result == ConnectivityResult.none || result == ConnectivityResult.other;
    
    if (_isOffline != isNowOffline) {
      _isOffline = isNowOffline;
      // Only notify if controller is initialized
      if (isControllerInitialized) {
        controller?.setOfflineMode(isNowOffline);
        // Only refresh if we're going from offline to online
        if (!isNowOffline) {
          refreshCurrentView();
        }
      }
      notifyListeners();
    }
  }
  
  /// Toggle selection mode
  void toggleSelectionMode() {
    _isInSelectionMode = !_isInSelectionMode;
    if (!_isInSelectionMode) {
      _selectedItems.clear();
    }
    notifyListeners();
  }
  
  /// Toggle item selection
  void toggleItemSelection(String itemId) {
    if (_selectedItems.contains(itemId)) {
      _selectedItems.remove(itemId);
    } else {
      _selectedItems.add(itemId);
    }
    notifyListeners();
  }
  
  /// Check if an item is selected
  bool isItemSelected(String itemId) {
    return _selectedItems.contains(itemId);
  }
  
  /// Get the count of selected items
  int get selectedItemCount => _selectedItems.length;
  
  /// Get the set of selected items
  Set<String> get selectedItems => _selectedItems;
  
  /// Check if in selection mode
  bool get isInSelectionMode => _isInSelectionMode;
  
  /// Check if offline
  bool get isOffline => _isOffline;
  
  /// Set offline mode
  void setOfflineMode(bool offline) {
    if (_isOffline != offline) {
      _isOffline = offline;
      // Only call controller methods if controller is initialized
      if (isControllerInitialized) {
        controller?.setOfflineMode(offline);
      }
      notifyListeners();
    }
  }
  
  /// Check if controller is initialized
  bool get isControllerInitialized => controller != null;
  
  /// Get selected browse items
  List<BrowseItem> getSelectedBrowseItems() {
    if (!isControllerInitialized) return [];
    return controller?.items.where((item) => _selectedItems.contains(item.id)).toList() ?? [];
  }
  
  /// Clear selection
  void clearSelection() {
    _selectedItems.clear();
    notifyListeners();
  }
  
  /// Exit selection mode
  void exitSelectionMode() {
    _isInSelectionMode = false;
    _selectedItems.clear();
    notifyListeners();
  }
  
  /// Refresh the current view
  Future<void> refreshCurrentView() async {
    EVLogger.debug('BrowseScreenState.refreshCurrentView called');
    if (!isControllerInitialized) {
      EVLogger.debug('BrowseScreenState.refreshCurrentView skipped - controller not initialized');
      return;
    }
    
    if (controller?.currentFolder != null) {
      EVLogger.debug('BrowseScreenState.refreshCurrentView - loading folder contents', 
          {'folderId': controller!.currentFolder!.id});
      await controller?.loadFolderContents(controller!.currentFolder!);
    } else {
      EVLogger.debug('BrowseScreenState.refreshCurrentView - loading departments');
      await controller?.loadDepartments();
    }
    EVLogger.debug('BrowseScreenState.refreshCurrentView completed');
  }
  
  /// Handle back button press
  /// Returns true if the back button press was handled, false otherwise
  bool handleBackButton() {
    // If controller is not initialized, can't handle back
    if (!isControllerInitialized) return false;
    
    // If in selection mode, exit selection mode
    if (_isInSelectionMode) {
      exitSelectionMode();
      return true;
    }
    
    // If we have a navigation stack, go back
    if (controller?.navigationStack.isNotEmpty ?? false) {
      final previousFolder = controller!.navigationStack.last;
      controller!.navigationStack.removeLast();
      controller!.loadFolderContents(previousFolder);
      return true;
    }
    
    // If we're not at the root level, go to root
    if (controller?.currentFolder != null && controller!.currentFolder!.id != 'root') {
      controller!.loadDepartments();
      return true;
    }
    
    // Can't handle back button press
    return false;
  }
  
  @override
  void dispose() {
    // Cancel connectivity subscription
    _connectivitySubscription.cancel();
    
    // Clean up controller if initialized
    if (isControllerInitialized) {
      controller?.dispose();
    }
    
    super.dispose();
  }

  @override
  void notifyListeners() {
    EVLogger.debug('BrowseScreenState.notifyListeners called');
    super.notifyListeners();
    EVLogger.debug('BrowseScreenState.notifyListeners completed');
  }
}
