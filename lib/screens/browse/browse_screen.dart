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
import 'package:eisenvaultappflutter/screens/browse/widgets/empty_folder_view.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/error_view.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/folder_content_list.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
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

  @override
  void initState() {
    super.initState();
    
    // Initialize delete service
    _deleteService = DeleteService(
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      customerHostname: widget.customerHostname,
    );
    
    // Initialize controllers and handlers
    _controller = BrowseScreenController(
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      instanceType: widget.instanceType,
      onStateChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    
    _fileTapHandler = FileTapHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      angoraBaseService: _controller.angoraBaseService,
    );
    
    _authHandler = AuthHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
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
      getSelectedItems: _getSelectedItems,
      onDeleteSuccess: _refreshCurrentFolder,
      clearSelectionMode: _clearSelectionMode,
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
    );
  }
  
  // Change this method to return Future<void>
  Future<void> _refreshCurrentFolder() async {
    if (_controller.currentFolder != null) {
      await _controller.loadFolderContents(_controller.currentFolder!);
    } else {
      await _controller.loadDepartments();
    }
  }
  
  List<BrowseItem> _getSelectedItems() {
    return _controller.items
        .where((item) => _selectedItems.contains(item.id))
        .toList();
  }
  
  void _clearSelectionMode() {
    setState(() {
      _isInSelectionMode = false;
      _selectedItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine when to show back arrow vs hamburger menu
    final bool isAtDepartmentsList = _controller.currentFolder == null || 
                                     _controller.currentFolder!.id == 'root';
    
    // Check if user has write permission for the current folder
    final bool hasWritePermission = _controller.currentFolder != null && 
                                   _controller.currentFolder!.id != 'root' &&
                                   _controller.currentFolder!.canWrite;
    
    // Update handlers that need current state
    _uploadHandler = UploadNavigationHandler(
      context: context,
      instanceType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      currentFolder: _controller.currentFolder,
      refreshCurrentFolder: _refreshCurrentFolder,
    );
    
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      appBar: BrowseAppBar(
        title: 'Departments',
        isAtDepartmentsList: isAtDepartmentsList,
        hasItems: _controller.items.isNotEmpty,
        isInSelectionMode: _isInSelectionMode,
        onBackPressed: () {
          if (_controller.navigationStack.isEmpty) {
            _controller.loadDepartments();
          } else {
            int parentIndex = _controller.navigationStack.length - 1;
            _controller.navigateToBreadcrumb(parentIndex);
          }
        },
        onSearchPressed: () => _searchHandler.navigateToSearch(),
        onSelectionModeToggle: () {
          setState(() {
            _isInSelectionMode = !_isInSelectionMode;
            _selectedItems.clear();
          });
        },
        onLogoutPressed: _authHandler.showLogoutConfirmation,
      ),
      // Only show drawer when at departments list
      drawer: isAtDepartmentsList ? BrowseDrawer(
        firstName: widget.firstName,
        baseUrl: widget.baseUrl,
        onLogoutTap: _authHandler.showLogoutConfirmation,
      ) : null,
      // Show appropriate FAB based on selection mode and permissions
      floatingActionButton: ActionButtonBuilder.buildFloatingActionButton(
        isInSelectionMode: _isInSelectionMode,
        hasSelectedItems: _selectedItems.isNotEmpty,
        isInFolder: _controller.currentFolder != null && _controller.currentFolder!.id != 'root',
        hasWritePermission: hasWritePermission,
        onBatchDelete: _batchDeleteHandler.handleBatchDelete,
        onUpload: _uploadHandler.navigateToUploadScreen,
        onShowNoPermissionMessage: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange,
            )
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Welcome, ${widget.firstName}!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Add breadcrumb navigation if we're not at root level
          if (_controller.currentFolder != null && _controller.currentFolder!.id != 'root')
            BreadcrumbNavigation(
              navigationStack: _controller.navigationStack,
              currentFolder: _controller.currentFolder,
              onRootTap: _controller.loadDepartments,
              onBreadcrumbTap: _controller.navigateToBreadcrumb,
            ),
          
          // Main content area
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  /// Builds the main content area (loading indicator, error, or item list)
  Widget _buildContent() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.errorMessage != null) {
      return ErrorView(
        errorMessage: _controller.errorMessage!,
        onRetry: _refreshCurrentFolder,
      );
    }
    
    if (_controller.items.isEmpty) {
      return const EmptyFolderView();
    }

    return FolderContentList(
      items: _controller.items,
      selectionMode: _isInSelectionMode,
      selectedItems: _selectedItems,
      onItemSelected: (String itemId, bool selected) {
        setState(() {
          if (selected) {
            _selectedItems.add(itemId);
          } else {
            _selectedItems.remove(itemId);
          }
        });
      },
      onFolderTap: _isInSelectionMode 
        ? (folder){} // Do nothing when in selection mode
        : (folder) => _controller.navigateToFolder(folder),
      onFileTap: _isInSelectionMode 
        ? (file) {} // Do nothing in selection mode
        : (file) {
            final fileType = FileTypeUtils.getFileType(file.name);
            if (fileType != FileType.unknown) {
              _fileTapHandler.handleFileTap(file);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Viewing "${file.name}" is not supported yet.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
      onDeleteTap: (BrowseItem item) {
        EVLogger.debug('Delete button tapped', {
          'itemId': item.id,
          'itemName': item.name,
        });
        _deleteHandler.showDeleteConfirmation(item);
      },
      showDeleteOption: false,
      onRefresh: _refreshCurrentFolder,
      onLoadMore: _controller.loadMoreItems,
      isLoadingMore: _controller.isLoadingMore,
      hasMoreItems: _controller.hasMoreItems,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
