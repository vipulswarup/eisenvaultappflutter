import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/browse/components/action_button_builder.dart';
import 'package:eisenvaultappflutter/screens/browse/components/browse_app_bar.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/auth_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/batch_delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/search_navigation_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/upload_navigation_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/breadcrumb_navigation.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/folder_content_list.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

/// The main browse screen that displays the repository content
class BrowseScreen extends StatefulWidget {
  final String baseUrl;
  final String authToken;
  final String firstName;
  final String instanceType;
  final String customerHostname;

  const BrowseScreen({
    super.key,
    required this.baseUrl,
    required this.authToken,
    required this.firstName,
    required this.instanceType,
    required this.customerHostname,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  // Connectivity variables
  final Connectivity _connectivity = Connectivity();
  bool _isOffline = false;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  
  // Controller and handlers
  late BrowseScreenController _controller;
  late FileTapHandler _fileTapHandler;
  late AuthHandler _authHandler;
  late DeleteHandler _deleteHandler;
  late DeleteService _deleteService;
  late BatchDeleteHandler _batchDeleteHandler;
  late UploadNavigationHandler _uploadHandler;
  late SearchNavigationHandler _searchHandler;
  
  // Selection mode state
  bool _isInSelectionMode = false;
  final Set<String> _selectedItems = {};

  // Offline manager
  final OfflineManager _offlineManager = OfflineManager.createDefault();

  // Define _refreshCurrentFolder first to avoid being referenced before declaration
  Future<void> _refreshCurrentFolder() async {
    if (_isOffline) {
      // In offline mode, load offline content
      await _loadOfflineContent();
    } else {
      if (_controller.currentFolder != null) {
        await _controller.loadFolderContents(_controller.currentFolder!);
      } else {
        await _controller.loadDepartments();
      }
    }
  }

  Future<void> _loadOfflineContent() async {
    try {
      setState(() {
        _controller.isLoading = true;
      });

      // Get offline items for current folder
      // If we're at the root level (no current folder), use null as parentId
      // Otherwise use the current folder's ID
      final String? parentId = _controller.currentFolder?.id == 'root' 
          ? null 
          : _controller.currentFolder?.id;
          
      final items = await _offlineManager.getOfflineItems(parentId);
      
      setState(() {
        _controller.items = items;
        _controller.isLoading = false;
        _controller.errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _controller.isLoading = false;
        _controller.errorMessage = 'Failed to load offline content: ${e.toString()}';
      });
    }
  }
  
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      EVLogger.error('Error checking connectivity', e);
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOffline = _isOffline;
    final isNowOffline = result == ConnectivityResult.none;
    
    if (wasOffline != isNowOffline) {
      setState(() {
        _isOffline = isNowOffline;
      });
      
      // If we just went offline, switch to offline content
      if (isNowOffline) {
        _loadOfflineContent();
      } else {
        // If we just came back online, refresh current folder
        _refreshCurrentFolder();
      }
      
      // Show appropriate message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowOffline 
              ? 'You are offline. Showing available offline content.' 
              : 'Back online. Refreshing content...'),
            backgroundColor: isNowOffline ? Colors.orange : Colors.green,
          ),
        );
      }
    }
  }

  // Add this method to handle offline toggle
  Future<void> _handleOfflineToggle(BrowseItem item) async {
    try {
      await _controller.toggleOfflineAvailability(item);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle offline availability: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add this method to check if an item is available offline
  Future<bool> _isItemAvailableOffline(String itemId) async {
    return await _controller.isItemAvailableOffline(itemId);
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize DeleteService first
    _deleteService = DeleteService(
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      customerHostname: widget.customerHostname,
    );
    
    // Initialize DeleteHandler
    _deleteHandler = DeleteHandler(
      context: context,
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      deleteService: _deleteService,
      onDeleteSuccess: () {
        _refreshCurrentFolder();
      },
    );
    
    // Initialize BatchDeleteHandler
    _batchDeleteHandler = BatchDeleteHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      deleteService: _deleteService,
      getSelectedItems: () => _controller.items.where((item) => _selectedItems.contains(item.id)).toList(),
      onDeleteSuccess: () {
        _refreshCurrentFolder();
      },
      clearSelectionMode: () {
        setState(() {
          _isInSelectionMode = false;
          _selectedItems.clear();
        });
      },
    );
    
    // Initialize controller
    _controller = BrowseScreenController(
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      instanceType: widget.instanceType,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    
    // Initialize handlers
    _fileTapHandler = FileTapHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
    );
    
    _authHandler = AuthHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
    );
    
    _uploadHandler = UploadNavigationHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      currentFolder: _controller.currentFolder,
      refreshCurrentFolder: _refreshCurrentFolder,
    );

    _searchHandler = SearchNavigationHandler(
      context: context,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      instanceType: widget.instanceType,
      navigateToFolder: _controller.navigateToFolder,
      openDocument: (document) {
        _fileTapHandler.handleFileTap(document);
      },
    );
    
    // Check initial connectivity
    _checkConnectivity();
    
    // Start listening to connectivity changes
    _connectivitySubscription = 
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    
    // Load initial content
    _refreshCurrentFolder();
  }

  @override
  Widget build(BuildContext context) {
    // Determine when to show back arrow vs hamburger menu
    final bool isAtDepartmentsList = _controller.currentFolder == null || 
                                     _controller.currentFolder!.id == 'root';
    
    // Check if user has write permission for the current folder
    final bool hasWritePermission = !_isOffline && // No write operations in offline mode
                                   _controller.currentFolder != null && 
                                   _controller.currentFolder!.id != 'root' &&
                                   _controller.currentFolder!.canWrite;
    
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      appBar: BrowseAppBar(
        title: _isOffline ? 'Offline Mode' : 'Departments',
        isAtDepartmentsList: isAtDepartmentsList,
        hasItems: _controller.items.isNotEmpty,
        isInSelectionMode: _isInSelectionMode,
        onBackPressed: () {
          if (_controller.navigationStack.isEmpty) {
            _controller.loadDepartments();
          } else if (_controller.navigationStack.length == 1) {
            // If only one item in stack, go back to departments
            _controller.loadDepartments();
          } else {
            // Navigate to the parent folder (one level up)
            int parentIndex = _controller.navigationStack.length - 2;
            _controller.navigateToBreadcrumb(parentIndex);
          }
        },
        onSearchPressed: _isOffline ? () {} : () => _searchHandler.navigateToSearch(), // Disable search in offline mode
        onSelectionModeToggle: () {
          setState(() {
            _isInSelectionMode = !_isInSelectionMode;
            _selectedItems.clear();
          });
        },
        onLogoutPressed: _authHandler.showLogoutConfirmation,
      ),
      // Only show drawer when at departments list and not in offline mode
      drawer: (!_isOffline && isAtDepartmentsList) ? BrowseDrawer(
        firstName: widget.firstName,
        baseUrl: widget.baseUrl,
        onLogoutTap: _authHandler.showLogoutConfirmation,
      ) : null,
      body: Column(
        children: [
          // Show offline banner if offline
          if (_isOffline)
            Container(
              width: double.infinity,
              color: Colors.orange.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.offline_pin, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode - Showing available offline content',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Breadcrumb navigation
          if (_controller.navigationStack.isNotEmpty)
            BreadcrumbNavigation(
              navigationStack: _controller.navigationStack,
              currentFolder: _controller.currentFolder,
              onRootTap: () => _controller.loadDepartments(),
              onBreadcrumbTap: (index) => _controller.navigateToBreadcrumb(index),
            ),
          
          // Main content
          Expanded(
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _controller.errorMessage != null
                    ? Center(
                        child: Text(
                          _controller.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshCurrentFolder,
                        child: FolderContentList(
                          items: _controller.items,
                          selectionMode: _isInSelectionMode,
                          selectedItems: _selectedItems,
                          onItemSelected: (itemId, selected) {
                            setState(() {
                              if (selected) {
                                _selectedItems.add(itemId);
                              } else {
                                _selectedItems.remove(itemId);
                              }
                            });
                          },
                          onFolderTap: (folder) {
                            _controller.navigateToFolder(folder);
                          },
                          onFileTap: (file) {
                            _fileTapHandler.handleFileTap(file);
                          },
                          onDeleteTap: !_isOffline ? _deleteHandler.showDeleteConfirmation : null, // Disable delete in offline mode
                          showDeleteOption: hasWritePermission && !_isOffline,
                          onRefresh: _refreshCurrentFolder,
                          onLoadMore: _controller.loadMoreItems,
                          isLoadingMore: _controller.isLoadingMore,
                          hasMoreItems: _controller.hasMoreItems,
                          isItemAvailableOffline: _controller.isItemAvailableOffline,
                          onOfflineToggle: !_isOffline ? _controller.toggleOfflineAvailability : null, // Disable offline toggle in offline mode
                        ),
                      ),
          ),
        ],
      ),
      // Only show FAB when not in offline mode
      floatingActionButton: !_isOffline && hasWritePermission
          ? _buildFloatingActionButton()
          : null,
    );
  }
  
  Widget _buildFloatingActionButton() {
    if (_isInSelectionMode) {
      return FloatingActionButton(
        onPressed: () async {
          await _batchDeleteHandler.handleBatchDelete();
        },
        child: const Icon(Icons.delete),
      );
    }

    return FloatingActionButton(
      onPressed: () async {
        await _uploadHandler.navigateToUploadScreen();
      },
      child: const Icon(Icons.upload),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _controller.dispose();
    super.dispose();
  }
}
