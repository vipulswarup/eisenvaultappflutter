import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

class ActionButtonBuilder {
  /// Builds the appropriate floating action button based on current state
  static Widget? buildFloatingActionButton({
    required bool isInSelectionMode,
    required bool hasSelectedItems,
    required bool isInFolder,
    required bool hasWritePermission,
    required VoidCallback onBatchDelete,
    required VoidCallback onUpload,
    required Function(String) onShowNoPermissionMessage,
  }) {
    // Show delete FAB when in selection mode with items selected
    if (isInSelectionMode && hasSelectedItems) {
      return FloatingActionButton(
        onPressed: onBatchDelete,
        backgroundColor: Colors.red,
        child: const Icon(Icons.delete),
      );
    } 
    
    // Show upload FAB when not in selection mode and in a folder
    if (!isInSelectionMode && isInFolder) {
      return FloatingActionButton(
        onPressed: hasWritePermission 
          ? onUpload
          : () {
              onShowNoPermissionMessage('You don\'t have permission to upload files to this folder.');
            },
        tooltip: hasWritePermission 
          ? 'Upload Document' 
          : 'You don\'t have permission to upload here',
        backgroundColor: hasWritePermission 
          ? EVColors.buttonErrorBackground 
          : Colors.grey,
        child: const Icon(Icons.upload_file),
      );
    }
    
    // No FAB in other situations
    return null;
  }
}
