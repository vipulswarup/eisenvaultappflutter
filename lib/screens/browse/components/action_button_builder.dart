import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ActionButtonBuilder {
  /// Builds the appropriate floating action button based on current state
  static Widget? buildFloatingActionButton({
    required bool isInSelectionMode,
    required bool hasSelectedItems,
    required bool isInFolder,
    required bool hasWritePermission,
    required VoidCallback onBatchDelete,
    required VoidCallback onCreateFolder,
    required VoidCallback onTakePicture,
    required VoidCallback onUploadFromGallery,
    required VoidCallback onUploadFromFilePicker,
    required Function(String) onShowNoPermissionMessage,
  }) {
    // Show delete FAB when in selection mode with items selected
    if (isInSelectionMode && hasSelectedItems) {
      return FloatingActionButton(
        onPressed: onBatchDelete,
        backgroundColor: EVColors.errorRed,
        child: const Icon(Icons.delete),
      );
    }

    // Show menu FAB when not in selection mode and in a folder
    if (!isInSelectionMode && isInFolder) {
      return hasWritePermission
          ? _UploadMenuFab(
              onCreateFolder: onCreateFolder,
              onTakePicture: onTakePicture,
              onUploadFromGallery: onUploadFromGallery,
              onUploadFromFilePicker: onUploadFromFilePicker,
            )
          : FloatingActionButton(
              onPressed: () {
                onShowNoPermissionMessage('You don\'t have permission to upload files to this folder.');
              },
              tooltip: 'You don\'t have permission to upload here',
              backgroundColor: EVColors.buttonDisabledBackground,
              child: const Icon(Icons.add),
            );
    }

    // No FAB in other situations
    return null;
  }
}

class _UploadMenuFab extends StatelessWidget {
  final VoidCallback onCreateFolder;
  final VoidCallback onTakePicture;
  final VoidCallback onUploadFromGallery;
  final VoidCallback onUploadFromFilePicker;

  const _UploadMenuFab({
    required this.onCreateFolder,
    required this.onTakePicture,
    required this.onUploadFromGallery,
    required this.onUploadFromFilePicker,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_UploadMenuAction>(
      icon: Container(
        decoration: const BoxDecoration(
          color: EVColors.buttonBackground,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: EVColors.cardShadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: const Icon(Icons.add, color: EVColors.buttonForeground, size: 28),
      ),
      color: EVColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onSelected: (action) {
        switch (action) {
          case _UploadMenuAction.createFolder:
            onCreateFolder();
            break;
          case _UploadMenuAction.takePicture:
            onTakePicture();
            break;
          case _UploadMenuAction.uploadFromGallery:
            onUploadFromGallery();
            break;
          case _UploadMenuAction.uploadFromFilePicker:
            onUploadFromFilePicker();
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<_UploadMenuAction>>[
          PopupMenuItem<_UploadMenuAction>(
            value: _UploadMenuAction.createFolder,
            child: Row(
              children: const [
                Icon(Icons.create_new_folder, color: EVColors.folderIconForeground),
                SizedBox(width: 12),
                Text('Create Folder', style: TextStyle(color: EVColors.textDefault)),
              ],
            ),
          ),
        ];
        // Only show Take Picture on iOS/Android (not web/desktop)
        final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
        if (isMobile) {
          items.add(const PopupMenuDivider(height: 1));
          items.add(
            PopupMenuItem<_UploadMenuAction>(
              value: _UploadMenuAction.takePicture,
              child: Row(
                children: const [
                  Icon(Icons.camera_alt, color: EVColors.infoBlue),
                  SizedBox(width: 12),
                  Text('Take Picture & Upload', style: TextStyle(color: EVColors.textDefault)),
                ],
              ),
            ),
          );
        }
        // Only show Gallery on iOS/Android
        if (isMobile) {
          items.add(const PopupMenuDivider(height: 1));
          items.add(
            PopupMenuItem<_UploadMenuAction>(
              value: _UploadMenuAction.uploadFromGallery,
              child: Row(
                children: const [
                  Icon(Icons.photo_library, color: EVColors.iconTeal),
                  SizedBox(width: 12),
                  Text('Upload from Photos/Gallery', style: TextStyle(color: EVColors.textDefault)),
                ],
              ),
            ),
          );
        }
        // Only show File Picker on iOS/Android/MacOS/Windows/Linux (not web)
        final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
        if (isMobile || isDesktop) {
          items.add(const PopupMenuDivider(height: 1));
          items.add(
            PopupMenuItem<_UploadMenuAction>(
              value: _UploadMenuAction.uploadFromFilePicker,
              child: Row(
                children: const [
                  Icon(Icons.upload_file, color: EVColors.buttonBackground),
                  SizedBox(width: 12),
                  Text('Upload Document', style: TextStyle(color: EVColors.textDefault)),
                ],
              ),
            ),
          );
        }
        return items;
      },
      tooltip: 'Upload or Create',
      offset: const Offset(0, -8),
    );
  }
}

enum _UploadMenuAction {
  createFolder,
  takePicture,
  uploadFromGallery,
  uploadFromFilePicker,
}
