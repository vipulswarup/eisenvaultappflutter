import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class BrowseScreenState extends ChangeNotifier {
  final BuildContext context;
  final String baseUrl;
  final String authToken;
  final String instanceType;
  final GlobalKey<ScaffoldState> scaffoldKey;
  
  // State variables
  bool isOffline = false;
  bool isInSelectionMode = false;
  final Set<String> selectedItems = {};
  
  // Controllers and managers
  late BrowseScreenController controller;
  late OfflineManager offlineManager;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  
  BrowseScreenState({
    required this.context,
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    required this.scaffoldKey,
  });

  Future<void> initialize() async {
    // Initialize offline manager
    offlineManager = await OfflineManager.createDefault();
    
    // Initialize controller
    controller = BrowseScreenController(
      baseUrl: baseUrl,
      authToken: authToken,
      instanceType: instanceType,
      onStateChanged: notifyListeners,
      context: context,
      scaffoldKey: scaffoldKey,
      offlineManager: offlineManager,
    );
    
    // Initialize connectivity monitoring
    await _initConnectivityListener();
    
    // Load initial content
    await controller.loadDepartments();
  }

  Future<void> _initConnectivityListener() async {
    // Check initial connectivity
    await _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(result);
    } catch (e) {
      EVLogger.error('Error checking connectivity', e);
      // If we can't check connectivity, assume we're offline
      await _updateConnectionStatus(ConnectivityResult.none);
    }
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    final wasOffline = isOffline;
    // Consider both ConnectivityResult.none and ConnectivityResult.other as offline states
    final isNowOffline = result == ConnectivityResult.none || result == ConnectivityResult.other;
    
    if (wasOffline != isNowOffline) {
      isOffline = isNowOffline;
      notifyListeners();
      
      if (isNowOffline) {
        EVLogger.debug('Device went offline - loading offline content');
        await _loadOfflineContent();
      } else {
        EVLogger.debug('Device went online - refreshing content');
        await refreshCurrentFolder();
      }
      
      _showConnectivitySnackBar(isNowOffline);
    }
  }

  void _showConnectivitySnackBar(bool isOffline) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isOffline 
          ? 'You are offline. Showing available offline content.' 
          : 'Back online. Refreshing content...'),
        backgroundColor: isOffline ? Colors.orange : Colors.green,
      ),
    );
  }

  Future<void> _loadOfflineContent() async {
    try {
      controller.isLoading = true;
      notifyListeners();

      final String? parentId = controller.currentFolder?.id == 'root' 
          ? null 
          : controller.currentFolder?.id;
          
      final items = await offlineManager.getOfflineItems(parentId);
      
      controller.items = items;
      controller.isLoading = false;
      controller.errorMessage = null;
      notifyListeners();
    } catch (e) {
      controller.isLoading = false;
      controller.errorMessage = 'Failed to load offline content: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> refreshCurrentFolder() async {
    if (isOffline) {
      await _loadOfflineContent();
    } else {
      if (controller.currentFolder != null) {
        await controller.loadFolderContents(controller.currentFolder!);
      } else {
        await controller.loadDepartments();
      }
    }
  }

  void toggleSelectionMode() {
    isInSelectionMode = !isInSelectionMode;
    if (!isInSelectionMode) {
      selectedItems.clear();
    }
    notifyListeners();
  }

  void toggleItemSelection(String itemId) {
    if (selectedItems.contains(itemId)) {
      selectedItems.remove(itemId);
    } else {
      selectedItems.add(itemId);
    }
    notifyListeners();
  }

  void selectAll() {
    if (selectedItems.length == controller.items.length) {
      selectedItems.clear();
    } else {
      selectedItems.addAll(controller.items.map((item) => item.id));
    }
    notifyListeners();
  }

  List<BrowseItem> getSelectedItems() {
    return controller.items.where((item) => selectedItems.contains(item.id)).toList();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    controller.dispose();
    super.dispose();
  }
} 