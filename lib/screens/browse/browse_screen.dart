import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/auth_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/file_tap_handler.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/breadcrumb_navigation.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/empty_folder_view.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/error_view.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/folder_content_list.dart';
import 'package:eisenvaultappflutter/screens/document_upload_screen.dart';
import 'package:eisenvaultappflutter/screens/browse/handlers/delete_handler.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';
import 'package:eisenvaultappflutter/services/permissions/permission_service.dart';
import 'package:eisenvaultappflutter/services/permissions/permission_service_factory.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

/// The main browse screen that displays the repository content
/// with navigation, actions, and item viewing capabilities
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

  // Selection mode state
  bool _isInSelectionMode = false;
  final Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize delete service with auth token
    _deleteService = DeleteService(
      repositoryType: widget.instanceType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      customerHostname: 'default-hostname', // May need to get from elsewhere
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
    final bool isAtDepartmentsList = _controller.currentFolder == null || 
                                     _controller.currentFolder!.id == 'root';
    
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
          // Only show selection mode toggle if there are items
          if (_controller.items.isNotEmpty)
            IconButton(
              icon: Icon(_isInSelectionMode ? Icons.cancel : Icons.select_all),
              tooltip: _isInSelectionMode ? 'Cancel selection' : 'Select items',
              onPressed: () {
                setState(() {
                  _isInSelectionMode = !_isInSelectionMode;
                  _selectedItems.clear(); // Clear selection when toggling mode
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _authHandler.showLogoutConfirmation,
          ),
        ],
      ),
      // Only show drawer when at departments list
      drawer: isAtDepartmentsList ? BrowseDrawer(
        firstName: widget.firstName,
        baseUrl: widget.baseUrl,
        onLogoutTap: _authHandler.showLogoutConfirmation,
      ) : null,
      // Show appropriate FAB based on selection mode and permissions
      floatingActionButton: _buildFloatingActionButton(hasWritePermission),
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

  /// Builds the appropriate floating action button based on current state
  Widget? _buildFloatingActionButton(bool hasWritePermission) {
    // Show delete FAB when in selection mode with items selected
    if (_isInSelectionMode && _selectedItems.isNotEmpty) {
      return FloatingActionButton(
        onPressed: _handleBatchDelete,
        backgroundColor: Colors.red,
        child: const Icon(Icons.delete),
      );
    } 
    
    // Show upload FAB when not in selection mode and in a folder
    if (!_isInSelectionMode && _controller.currentFolder != null && 
        _controller.currentFolder!.id != 'root') {
      return FloatingActionButton(
        onPressed: hasWritePermission 
          ? _navigateToUploadScreen
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
          ? EVColors.buttonErrorBackground 
          : Colors.grey,
      );
    }
    
    // No FAB in other situations
    return null;
  }

  /// Navigate to the upload screen to add files to the current folder
  void _navigateToUploadScreen() async {
    if (_controller.currentFolder == null) return;
  
    // Get the correct parent folder ID
    String parentFolderId;
  
    if (_controller.instanceType.toLowerCase() == 'angora') {
      // For Angora, we use the current folder ID directly
      parentFolderId = _controller.currentFolder!.id;
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
    if (result == true && _controller.currentFolder != null) {
      _controller.loadFolderContents(_controller.currentFolder!);
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
      // Pass selection mode state
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
  : (folder) {
      // Call the async method without awaiting
      _controller.navigateToFolder(folder);
    },

onFileTap: _isInSelectionMode 
  ? (file) {} // Empty function that does nothing
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

      // Fix the type mismatch by using a synchronous function
      onDeleteTap: (BrowseItem item) {
        // Call the async function but don't await it
        _deleteHandler.showDeleteConfirmation(item);
      },
      // Don't show delete option by default
      showDeleteOption: false,
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

  /// Handle batch delete operation for selected items
  Future<void> _handleBatchDelete() async {
    try {
      // Get the selected items
      final itemsToDelete = _controller.items
          .where((item) => _selectedItems.contains(item.id))
          .toList();
          
      if (itemsToDelete.isEmpty) return;
      
      // Show permission checking dialog
      bool canProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => FutureBuilder<bool>(
          future: _checkDeletePermissions(itemsToDelete),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                title: const Text('Checking permissions'),
                content: const LinearProgressIndicator(),
              );
            }
            
            final hasPermission = snapshot.data ?? false;
            // Close dialog and return result
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pop(hasPermission);
            });
            
            return AlertDialog(
              title: const Text('Checking permissions'),
              content: const LinearProgressIndicator(),
            );
          }
        )
      ) ?? false;
      
      if (canProceed) {
        // Show confirmation dialog
        bool confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete ${itemsToDelete.length} items?'),
            content: const Text('This action cannot be undone.'),
                        actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ?? false;
        
        if (confirmed) {
          // Show progress dialog during deletion
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              title: Text('Deleting items'),
              content: LinearProgressIndicator(),
            ),
          );
          
          try {
            // Process deletions by type
            final folders = itemsToDelete.where((item) => item.type == 'folder').toList();
            final documents = itemsToDelete.where((item) => item.type != 'folder').toList();
            final departments = itemsToDelete.where((item) => item.isDepartment).toList();
            
            // Delete each type using appropriate method
            if (departments.isNotEmpty) {
              await _deleteService.deleteDepartments(
                departments.map((item) => item.id).toList()
              );
            }
            
            if (folders.isNotEmpty) {
              await _deleteService.deleteFolders(
                folders.map((item) => item.id).toList()
              );
            }
            
            if (documents.isNotEmpty) {
              await _deleteService.deleteFiles(
                documents.map((item) => item.id).toList()
              );
            }
            
            // Close progress dialog
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            
            // Show success message
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Successfully deleted ${itemsToDelete.length} items'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.green,
                )
              );
            }
            
            // Clear selection mode
            setState(() {
              _isInSelectionMode = false;
              _selectedItems.clear();
            });
            
            // Refresh the folder
            if (_controller.currentFolder != null) {
              _controller.loadFolderContents(_controller.currentFolder!);
            } else {
              _controller.loadDepartments();
            }
          } catch (e) {
            // Close progress dialog
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            
            // Show error message
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error deleting items: ${e.toString()}'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.red,
                )
              );
            }
          }
        }
      } else {
        // Show error if user doesn't have permission
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You don\'t have permission to delete some of these items'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          )
        );
      }
    } catch (e) {
      // Handle general errors in batch delete process
      EVLogger.error('Error in batch delete', {'error': e.toString()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing delete: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        )
      );
    }
  }

  /// Check if the user has permission to delete all selected items
  Future<bool> _checkDeletePermissions(List<BrowseItem> items) async {
    // For Angora repositories, use PermissionService
    if (widget.instanceType.toLowerCase() == 'angora') {
      final permissionService = PermissionServiceFactory.getService(
        widget.instanceType,
        widget.baseUrl,
        widget.authToken,
      );
      
      // Check each item for delete permission
      for (final item in items) {
        try {
          final hasPermission = await permissionService.hasPermission(item.id, 'delete');
          if (!hasPermission) {
            return false; // If any item fails, return false
          }
        } catch (e) {
          EVLogger.error('Error checking permission', {
            'itemId': item.id,
            'error': e.toString()
          });
          return false; // Assume no permission on error
        }
      }
      return true; // All items passed
    } else {
      // For Classic/Alfresco repositories, use the item's canDelete property
      return items.every((item) => item.canDelete);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

