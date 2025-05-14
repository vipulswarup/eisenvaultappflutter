import 'package:flutter/material.dart';
import '../../../screens/document_upload_screen.dart';
import '../../../screens/browse/browse_screen_controller.dart';

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

  /// Navigate to the upload screen to add files to the current folder
  Future<void> navigateToUploadScreen() async {
    // Get the current folder from the controller
    final currentFolder = controller.currentFolder;
    
    if (currentFolder == null) {
      _showErrorMessage('Please select a folder to upload files');
      return;
    }
  
    // Get the correct parent folder ID
    String parentFolderId;
  
    if (instanceType.toLowerCase() == 'angora') {
      // For Angora, we use the current folder ID directly
      parentFolderId = currentFolder.id;
    } else {
      // For Alfresco/Classic, handle documentLibrary ID
      if (currentFolder.isDepartment) {
        if (currentFolder.documentLibraryId != null) {
          parentFolderId = currentFolder.documentLibraryId!;
        } else {
          _showErrorMessage('Cannot upload at this level. Please navigate to a subfolder.');
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
  
    // If upload was successful, refresh the current folder
    if (result == true) {
      refreshCurrentFolder();
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      )
    );
  }
}
