import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/delete/delete_service.dart';
import 'package:eisenvaultappflutter/widgets/delete_confirmation_dialog.dart';
import 'package:eisenvaultappflutter/services/permissions/angora_permission_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Handles UI interactions related to deleting repository items
class DeleteHandler {
  final BuildContext context;
  final String repositoryType;
  final String baseUrl;
  final String authToken;
  final DeleteService deleteService;
  final Function onDeleteSuccess;

  DeleteHandler({
    required this.context,
    required this.repositoryType,
    required this.baseUrl,
    required this.authToken,
    required this.deleteService,
    required this.onDeleteSuccess,
  });

  // Add a permission cache to avoid repeated calls
  static final Map<String, bool> _permissionCache = {};

  /// Check if the user has permission to delete the specified item
  Future<bool> _checkDeletePermission(BrowseItem item) async {
    // Check if this is a system folder - system folders cannot be deleted
    if (item.isSystemFolder) {
      return false;
    }
    
    // Check cache first
    if (_permissionCache.containsKey(item.id)) {
      return _permissionCache[item.id]!;
    }
    
    try {
      bool result;
      if (repositoryType.toLowerCase() == 'angora') {
        
        final permissionService = AngoraPermissionService(baseUrl, authToken);
        result = await permissionService.hasPermission(item.id, 'delete');
        
      } else {
        result = item.canDelete;
      }
      
      // Cache the result
      _permissionCache[item.id] = result;
      return result;
    } catch (e) {
      EVLogger.error('Error checking delete permissions', {
        'error': e.toString(), 
        'itemId': item.id,
        'itemName': item.name
      });
      return false;
    }
  }


  /// Show an error message to the user
  void _showErrorMessage(BuildContext context, String message) {
    // Use the provided context to ensure we're showing the message in the right place
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show a success message to the user
  void _showSuccessMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Main entry point - show delete confirmation for an item
  Future<void> showDeleteConfirmation(BrowseItem item) async {
    
    try {
      // Show loading indicator while checking permissions
      bool hasPermission = false;
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          // Start the permission check
          _checkDeletePermission(item).then((result) {
            hasPermission = result;
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          }).catchError((error) {
            hasPermission = false;
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          });
          
          // Show loading indicator
          return const Center(child: CircularProgressIndicator());
        }
      );
      
      // If user doesn't have permission, show error and exit
      if (!hasPermission || !context.mounted) {
        if (context.mounted) {
          if (item.isSystemFolder) {
            _showErrorMessage(context, 'System folders cannot be deleted');
          } else {
            _showErrorMessage(context, 'You don\'t have permission to delete this item');
          }
        }
        return;
      }
      
      // Show delete confirmation dialog
      final itemType = _getItemTypeLabel(item);
      
      if (!context.mounted) return;
      
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              bool isDeleting = false;
              
              return DeleteConfirmationDialog(
                title: 'Delete ${item.name}',
                content: 'Are you sure you want to delete this $itemType? This action cannot be undone.',
                isLoading: isDeleting,
                onConfirm: () async {
                  // Set loading state
                  setState(() {
                    isDeleting = true;
                  });
                  
                  try {
                    // Perform the delete operation
                    final result = await _performDelete(item);
                    
                    // Close dialog and show success message
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      _showSuccessMessage(context, result);
                    }
                    
                    // Notify parent to refresh
                    onDeleteSuccess();
                  } catch (e) {
                    // Close dialog and show error message
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    
                    if (context.mounted) {
                      _showErrorMessage(context, 'Failed to delete: ${e.toString()}');
                    }
                  }
                },
              );
            }
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        _showErrorMessage(context, 'Error checking permissions: ${e.toString()}');
      }
    }
  }

  /// Get a user-friendly label for the item type
  String _getItemTypeLabel(BrowseItem item) {
    if (item.isDepartment) return 'department';
    if (item.type == 'folder') return 'folder';
    return 'document';
  }

  /// Perform the delete operation based on item type
  Future<String> _performDelete(BrowseItem item) async {
    try {
      if (item.isDepartment) {
        return await deleteService.deleteDepartments([item.id]);
      } else if (item.type == 'folder') {
        return await deleteService.deleteFolders([item.id]);
      } else {
        return await deleteService.deleteFiles([item.id]);
      }
    } catch (e) {
      EVLogger.error('Error in _performDelete', {
        'error': e.toString(),
        'itemId': item.id,
        'itemType': item.type,
        'itemName': item.name
      });
      rethrow;
    }
  }
}
