import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/delete_service.dart';
import 'package:eisenvaultappflutter/widgets/delete_confirmation_dialog.dart';
import 'package:eisenvaultappflutter/services/browse/angora_browse_service.dart';

class DeleteHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final DeleteService deleteService;
  final Function onDeleteSuccess;

  DeleteHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.deleteService,
    required this.onDeleteSuccess,
  });

  void showDeleteConfirmation(BrowseItem item) async {
    // Show loading indicator
    final loadingDialog = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Check if the user has delete permission
      bool canDelete = false;
      
      if (instanceType.toLowerCase() == 'angora') {
        // Get the Angora browse service
        final browseService = AngoraBrowseService(baseUrl, authToken);
        
        // Check if the user has delete permission
        canDelete = await browseService.hasPermission(item.id, 'delete');
      } else {
        // For Alfresco, use the existing canDelete property
        canDelete = item.canDelete;
      }
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      if (!canDelete) {
        // Show error message if the user doesn't have delete permission
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You don\'t have permission to delete this item'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Show delete confirmation dialog
      String itemType = item.isDepartment 
          ? 'department' 
          : (item.type == 'folder' ? 'folder' : 'document');
      
      showDialog(
        context: context,
        builder: (context) {
          bool isDeleting = false;
          
          return StatefulBuilder(
            builder: (context, setState) {
              return DeleteConfirmationDialog(
                title: 'Delete ${item.name}',
                content: 'Are you sure you want to delete this $itemType? This action cannot be undone.',
                isLoading: isDeleting,
                onConfirm: () async {
                  setState(() {
                    isDeleting = true;
                  });
                  
                  try {
                    String message;
                    
                    if (item.isDepartment) {
                      message = await deleteService.deleteDepartments(
                        [item.id],
                        instanceType.toLowerCase(),
                      );
                    } else if (item.type == 'folder') {
                      message = await deleteService.deleteFolders(
                        [item.id],
                        instanceType.toLowerCase(),
                      );
                    } else {
                      message = await deleteService.deleteFiles(
                        [item.id],
                        instanceType.toLowerCase(),
                      );
                    }
                    
                    Navigator.of(context).pop(); // Close dialog
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    onDeleteSuccess();
                  } catch (e) {
                    Navigator.of(context).pop(); // Close dialog
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete: $e'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              );
            }
          );
        },
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check delete permission: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
