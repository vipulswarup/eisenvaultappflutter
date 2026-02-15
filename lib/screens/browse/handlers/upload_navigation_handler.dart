import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';
import 'package:eisenvaultappflutter/screens/document_upload_screen.dart';

/// Navigates to the file-picker upload screen.
class UploadNavigationHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final Function() refreshCurrentFolder;
  final BrowseScreenController controller;

  UploadNavigationHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.refreshCurrentFolder,
    required this.controller,
  });

  /// Navigate to the upload screen to add files to the current folder.
  Future<void> navigateToUploadScreen() async {
    final currentFolder = controller.currentFolder;
    if (currentFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a folder to upload files'),
          backgroundColor: EVColors.statusError,
        ),
      );
      return;
    }

    String parentFolderId;
    if (instanceType.toLowerCase() == 'angora') {
      parentFolderId = currentFolder.id;
    } else {
      if (currentFolder.isDepartment) {
        if (currentFolder.documentLibraryId != null) {
          parentFolderId = currentFolder.documentLibraryId!;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cannot upload at this level. Please navigate to a subfolder.'),
              backgroundColor: EVColors.statusError,
            ),
          );
          return;
        }
      } else {
        parentFolderId = currentFolder.id;
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentUploadScreen(
          repositoryType: instanceType,
          parentFolderId: parentFolderId,
          baseUrl: baseUrl,
          authToken: authToken,
        ),
      ),
    );

    if (result == true) {
      refreshCurrentFolder();
    }
  }
}
