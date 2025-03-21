import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/auth_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/breadcrumb_navigation.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/empty_folder_view.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/error_view.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/folder_content_list.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/screens/document_upload_screen.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/delete_handler.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';


class BrowseScreen extends StatefulWidget {
  final String baseUrl;
  final String authToken;
  final String firstName;
  final String instanceType;

  const BrowseScreen({
    super.key,
    required this.baseUrl,
    required this.authToken,
    required this.firstName,
    required this.instanceType,
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

  @override
  void initState() {
    super.initState();
    // Initialize delete service directly with auth token
    _deleteService = DeleteService(
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      customerHostname: 'default-hostname', // You may need to get this from somewhere else
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
        // Refresh the current folder after successful deletion
        if (_controller.currentFolder != null) {
          _controller.loadFolderContents(_controller.currentFolder!);
        } else {
          _controller.loadDepartments();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine when to show back arrow vs hamburger menu
    final bool isAtDepartmentsList = _controller.currentFolder == null || _controller.currentFolder!.id == 'root';
    
    // Check if user has write permission for the current folder
    final bool hasWritePermission = _controller.currentFolder != null && 
                                   _controller.currentFolder!.id != 'root' &&
                                   _controller.currentFolder!.canWrite;
    
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      appBar: AppBar(
        // Show hamburger icon at departments list, back arrow inside folders
        leading: isAtDepartmentsList
            ? null  // Use default drawer hamburger icon
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_controller.navigationStack.isEmpty) {
                    // If at department root, go back to departments list
                    _controller.loadDepartments();
                  } else {
                    // If in subfolder, go back one level by navigating to parent folder
                    int parentIndex = _controller.navigationStack.length - 1;
                    _controller.navigateToBreadcrumb(parentIndex);
                  }
                },
              ),
        title: const Text('Departments'),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _authHandler.showLogoutConfirmation,
          ),
        ],
      ),
      // Keep the drawer to be shown with hamburger menu when appropriate
      drawer: isAtDepartmentsList ? BrowseDrawer(
        firstName: widget.firstName,
        baseUrl: widget.baseUrl,
        onLogoutTap: _authHandler.showLogoutConfirmation,
      ) : null,
      // Modified floating action button with permission check
      floatingActionButton: _controller.currentFolder != null && _controller.currentFolder!.id != 'root' ? 
        FloatingActionButton(
          onPressed: hasWritePermission 
            ? () => _navigateToUploadScreen() 
            : () {
                // Show message explaining why button is disabled
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You don\'t have permission to upload files to this folder.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.orange,
                  )
                );
              },
          child: const Icon(Icons.upload_file),
          tooltip: hasWritePermission 
            ? 'Upload Document' 
            : 'You don\'t have permission to upload here',
          backgroundColor: hasWritePermission 
            ? EVColors.terracotta 
            : Colors.grey,
        ) : null,
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
          
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  void _navigateToUploadScreen() async {
    if (_controller.currentFolder == null) return;
  
    // Get the correct parent folder ID
    String parentFolderId;
  
    if (_controller.instanceType.toLowerCase() == 'angora') {
      // For Angora, we use the current folder ID directly
      parentFolderId = _controller.currentFolder!.id;
    
      EVLogger.debug('Angora upload: Using folder ID directly', {
        'parentFolderId': parentFolderId
      });
    } else {
      // For Alfresco/Classic, handle documentLibrary ID
      if (_controller.currentFolder!.isDepartment) {
        if (_controller.currentFolder!.documentLibraryId != null) {
          parentFolderId = _controller.currentFolder!.documentLibraryId!;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot upload at this level. Please navigate to a subfolder.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            )
          );
          return;
        }
      } else {
        parentFolderId = _controller.currentFolder!.id;
      }
    }
  
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentUploadScreen(
          repositoryType: widget.instanceType,
          parentFolderId: parentFolderId,
          baseUrl: widget.baseUrl,
          authToken: widget.authToken,
        ),
      ),
    );
  
    // If upload was successful, refresh the current folder
    if (result == true) {
      // Just refresh the current folder without modifying the navigation stack
      if (_controller.currentFolder != null) {
        _controller.loadFolderContents(_controller.currentFolder!);
      }
    }
  }
  /// Builds the main content area (loading indicator, error, or item list)
  Widget _buildContent() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.errorMessage != null) {
      return ErrorView(
        errorMessage: _controller.errorMessage!,
        onRetry: () {
          if (_controller.currentFolder != null) {
            _controller.loadFolderContents(_controller.currentFolder!);
          } else {
            _controller.loadDepartments();
          }
        },
      );
    }
    
    if (_controller.items.isEmpty) {
      return const EmptyFolderView();
    }

    return FolderContentList(
      items: _controller.items,
      onFolderTap: _controller.navigateToFolder,
      onFileTap: (file) {
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
      onDeleteTap: (item) => _deleteHandler.showDeleteConfirmation(item),
      showDeleteOption: true, // Enable delete option
      onRefresh: () {
        return _controller.currentFolder != null
            ? _controller.loadFolderContents(_controller.currentFolder!)
            : _controller.loadDepartments();
      },
      onLoadMore: _controller.loadMoreItems,
      isLoadingMore: _controller.isLoadingMore,
      hasMoreItems: _controller.hasMoreItems,
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // Make sure your controller has a dispose method
    super.dispose();
  }
}
