import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/rename/rename_service.dart';
import 'package:eisenvaultappflutter/services/permissions/angora_permission_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';

/// Handles UI interactions related to renaming repository items
class RenameHandler {
  final BuildContext context;
  final String repositoryType;
  final String baseUrl;
  final String authToken;
  final RenameService renameService;
  final Function onRenameSuccess;

  RenameHandler({
    required this.context,
    required this.repositoryType,
    required this.baseUrl,
    required this.authToken,
    required this.renameService,
    required this.onRenameSuccess,
  });

  // Add a permission cache to avoid repeated calls
  static final Map<String, bool> _permissionCache = {};

  /// Check if the user has permission to rename the specified item
  Future<bool> _checkRenamePermission(BrowseItem item) async {
    // Check if this is a system folder - system folders cannot be renamed
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
        result = await permissionService.hasPermission(item.id, 'update');
      } else {
        result = item.allowableOperations?.contains('update') ?? false;
      }
      
      // Cache the result
      _permissionCache[item.id] = result;
      return result;
    } catch (e) {
      EVLogger.error('Error checking rename permissions', {
        'error': e.toString(), 
        'itemId': item.id,
        'itemName': item.name
      });
      return false;
    }
  }

  /// Show an error message to the user
  void _showErrorMessage(BuildContext context, String message) {
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

  /// Main entry point - show rename dialog for an item
  Future<void> showRenameDialog(BrowseItem item) async {
    try {
      // Show loading indicator while checking permissions
      bool hasPermission = false;
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          // Start the permission check
          _checkRenamePermission(item).then((result) {
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
            _showErrorMessage(context, 'System folders cannot be renamed');
          } else {
            _showErrorMessage(context, 'You don\'t have permission to rename this item');
          }
        }
        return;
      }
      
      // Show rename dialog
      final itemType = _getItemTypeLabel(item);
      
      if (!context.mounted) return;
      
      final TextEditingController nameController = TextEditingController(text: item.name);
      
      bool isRenaming = false;
      
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: EVColors.cardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Rename ${item.name}', style: const TextStyle(color: EVColors.textDefault)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter a new name for this $itemType:',
                      style: const TextStyle(color: EVColors.textDefault),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'New Name',
                        labelStyle: TextStyle(color: EVColors.textFieldLabel),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: EVColors.textFieldBorder),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: EVColors.buttonBackground),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isRenaming ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('CANCEL', style: TextStyle(color: EVColors.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EVColors.buttonBackground,
                      foregroundColor: EVColors.buttonForeground,
                    ),
                    onPressed: isRenaming ? null : () async {
                      final newName = nameController.text.trim();
                      if (newName.isEmpty) {
                        _showErrorMessage(context, 'Name cannot be empty');
                        return;
                      }
                      if (newName == item.name) {
                        Navigator.of(dialogContext).pop();
                        return;
                      }
                      
                      // Set loading state
                      setState(() {
                        isRenaming = true;
                      });
                      
                      try {
                        // Perform the rename operation
                        final result = await _performRename(item, newName);
                        
                        // Close dialog and show success message
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          _showSuccessMessage(context, result);
                        }
                        
                        // Notify parent to refresh
                        onRenameSuccess();
                      } catch (e) {
                        // Close dialog and show error message
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        
                        if (context.mounted) {
                          _showErrorMessage(context, 'Failed to rename: ${e.toString()}');
                        }
                      }
                    },
                    child: isRenaming 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('RENAME'),
                  ),
                ],
              );
            },
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

  /// Perform the rename operation
  Future<String> _performRename(BrowseItem item, String newName) async {
    try {
      return await renameService.renameItem(item, newName);
    } catch (e) {
      EVLogger.error('Error in _performRename', {
        'error': e.toString(),
        'itemId': item.id,
        'itemType': item.type,
        'itemName': item.name,
        'newName': newName
      });
      rethrow;
    }
  }
} 