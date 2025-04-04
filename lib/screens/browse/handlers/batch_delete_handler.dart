import 'package:flutter/material.dart';
import '../../../models/browse_item.dart';
import '../../../services/delete/delete_service.dart';
import '../../../services/permissions/permission_service_factory.dart';
import '../../../utils/logger.dart';

class BatchDeleteHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final DeleteService deleteService;
  final List<BrowseItem> Function() getSelectedItems;
  final VoidCallback onDeleteSuccess;
  final VoidCallback clearSelectionMode;

  BatchDeleteHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.deleteService,
    required this.getSelectedItems,
    required this.onDeleteSuccess,
    required this.clearSelectionMode,
  });

  /// Handle batch delete operation for selected items
  Future<void> handleBatchDelete() async {
    try {
      // Get the selected items
      final itemsToDelete = getSelectedItems();
          
      if (itemsToDelete.isEmpty) return;
      
      // Show permission checking dialog
      bool canProceed = await _checkPermissions(itemsToDelete);
      
      if (canProceed) {
        // Show confirmation dialog
        bool confirmed = await _showConfirmationDialog(itemsToDelete.length);
        
        if (confirmed) {
          await _performDelete(itemsToDelete);
        }
      } else {
        // Show error if user doesn't have permission
        _showMessage(
          'You don\'t have permission to delete some of these items',
          Colors.orange,
        );
      }
    } catch (e) {
      // Handle general errors in batch delete process
      EVLogger.error('Error in batch delete', {'error': e.toString()});
      _showMessage(
        'Error processing delete: ${e.toString()}',
        Colors.red,
      );
    }
  }

  /// Check permissions for batch deletion
  Future<bool> _checkPermissions(List<BrowseItem> items) async {
    if (!context.mounted) return false;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FutureBuilder<bool>(
        future: _checkDeletePermissions(items),
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
  }

  /// Show confirmation dialog for deletion
  Future<bool> _showConfirmationDialog(int itemCount) async {
    if (!context.mounted) return false;
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $itemCount items?'),
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
  }

  /// Perform the actual deletion
  Future<void> _performDelete(List<BrowseItem> itemsToDelete) async {
    if (!context.mounted) return;
    
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
        await deleteService.deleteDepartments(
          departments.map((item) => item.id).toList()
        );
      }
      
      if (folders.isNotEmpty) {
        await deleteService.deleteFolders(
          folders.map((item) => item.id).toList()
        );
      }
      
      if (documents.isNotEmpty) {
        await deleteService.deleteFiles(
          documents.map((item) => item.id).toList()
        );
      }
      
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Show success message
      if (context.mounted) {
        _showMessage(
          'Successfully deleted ${itemsToDelete.length} items',
          Colors.green,
        );
      }
      
      // Clear selection mode
      clearSelectionMode();
      
      // Refresh the folder
      onDeleteSuccess();
    } catch (e) {
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (context.mounted) {
        _showMessage(
          'Error deleting items: ${e.toString()}',
          Colors.red,
        );
      }
    }
  }

  /// Check if the user has permission to delete all selected items
  Future<bool> _checkDeletePermissions(List<BrowseItem> items) async {
    // For Angora repositories, use PermissionService
    if (instanceType.toLowerCase() == 'angora') {
      final permissionService = PermissionServiceFactory.getService(
        instanceType,
        baseUrl,
        authToken,
      );
      
      // Check each item for delete permission
      for (final item in items) {
        EVLogger.debug('Checking delete permission for item: ${item.id} - ${item.name}');
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

  /// Show a message to the user
  void _showMessage(String message, Color backgroundColor) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
      )
    );
  }
}
