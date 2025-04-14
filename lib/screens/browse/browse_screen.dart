import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/auth_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/batch_delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/delete_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/search_navigation_handler.dart';
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

class UploadNavigationHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final BrowseItem? currentFolder;
  final Function() refreshCurrentFolder;

  UploadNavigationHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.currentFolder,
    required this.refreshCurrentFolder,
  });

  /// Navigate to the upload screen to add files to the current folder
  Future<void> navigateToUploadScreen() async {
    // Method implementation...
  }

 
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

  // Global key for scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _forceOfflineMode = false;

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
  
  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOffline = _isOffline;
    // Consider both ConnectivityResult.none and ConnectivityResult.other as offline states
    final isNowOffline = _forceOfflineMode || result == ConnectivityResult.none || result == ConnectivityResult.other;
    
    if (wasOffline != isNowOffline) {
      setState(() {
        _isOffline = isNowOffline;
      });
      
      if (isNowOffline) {
        EVLogger.debug('Device went offline - loading offline content');
        _loadOfflineContent();
      } else {
        EVLogger.debug('Device went online - refreshing content');
        _refreshCurrentFolder();
      }
      
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

  bool _shouldShowOfflineToggle() {
    return _offlineManager.hasOfflineContent() != null;
  }

  @override
  void initState() {
    super.initState();
    
    _deleteService = DeleteService(
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      customerHostname: widget.customerHostname,
    );
    
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
    
    // Initialize controller with context
    _controller = BrowseScreenController(
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      instanceType: widget.instanceType,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      context: context,
      scaffoldKey: _scaffoldKey,
      offlineManager: _offlineManager,
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
    
    EVLogger.debug('BrowseScreen build conditions', {
      'isOffline': _isOffline,
      'isAtDepartmentsList': isAtDepartmentsList,
      'currentFolderId': _controller.currentFolder?.id,
      'currentFolderCanWrite': _controller.currentFolder?.canWrite,
      'hasWritePermission': hasWritePermission,
      'isInSelectionMode': _isInSelectionMode,
      'selectedItemsCount': _selectedItems.length,
    });
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: EVColors.screenBackground,
      appBar: AppBar(
        title: _isOffline ? const Text('Offline Mode') : const Text('Departments'),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        leading: isAtDepartmentsList
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
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
            ),
        actions: [
          // Add offline mode toggle
          Row(
            children: [
              const Text('Test Offline', 
                style: TextStyle(fontSize: 12),
              ),
              Switch(
                value: _forceOfflineMode,
                activeColor: Colors.orange,
                onChanged: (value) {
                  setState(() {
                    _forceOfflineMode = value;
                    _updateConnectionStatus(value 
                      ? ConnectivityResult.none 
                      : ConnectivityResult.mobile);
                  });
                },
              ),
            ],
          ),
          if (!_isOffline) // Only show search in online mode
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _searchHandler.navigateToSearch(),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _authHandler.showLogoutConfirmation,
          ),
        ],
        // Rest of the AppBar code...
      ),
      // Only show drawer when at departments list and not in offline mode
      drawer: (!_isOffline && isAtDepartmentsList) ? BrowseDrawer(
        firstName: widget.firstName,
        baseUrl: widget.baseUrl,
        authToken: widget.authToken,
        instanceType: widget.instanceType,
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
      // Show FAB for delete in selection mode, or for upload when online with write permission
      floatingActionButton: _isInSelectionMode || (!_isOffline && hasWritePermission)
          ? _buildFloatingActionButton()
          : null,
    );
  }
  
  Widget _buildFloatingActionButton() {
    EVLogger.debug('Building FAB', {
      'isInSelectionMode': _isInSelectionMode,
      'selectedItemsCount': _selectedItems.length,
      'isOffline': _isOffline,
      'hasWritePermission': !_isOffline && 
                          _controller.currentFolder != null && 
                          _controller.currentFolder!.id != 'root' &&
                          _controller.currentFolder!.canWrite,
    });
    
    if (_isInSelectionMode && _selectedItems.isNotEmpty) {
      return FloatingActionButton(
        onPressed: () async {
          await _batchDeleteHandler.handleBatchDelete();
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.delete),
      );
    }
  
    // For upload when not in selection mode
    return FloatingActionButton(
      onPressed: () {
        _uploadHandler.navigateToUploadScreen();
      },
      backgroundColor: EVColors.uploadButtonBackground,
      foregroundColor: EVColors.uploadButtonForeground,
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
