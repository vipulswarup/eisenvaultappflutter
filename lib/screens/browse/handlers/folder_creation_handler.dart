import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Handles folder creation for both Angora and Classic repositories.
class FolderCreationHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final String customerHostname;
  final Future<void> Function() onFolderCreated;

  FolderCreationHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.customerHostname,
    required this.onFolderCreated,
  });

  /// Show a dialog to get the folder name, then create it.
  Future<void> showCreateFolderDialog(String parentFolderId) async {
    final folderNameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EVColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Folder', style: TextStyle(color: EVColors.textDefault)),
        content: TextField(
          controller: folderNameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            labelStyle: TextStyle(color: EVColors.textFieldLabel),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: EVColors.textFieldBorder),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: EVColors.buttonBackground),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: EVColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EVColors.buttonBackground,
              foregroundColor: EVColors.buttonForeground,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(folderNameController.text.trim()),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
    folderNameController.dispose();
    if (result != null && result.isNotEmpty) {
      await _createFolder(result, parentFolderId);
    }
  }

  Future<void> _createFolder(String folderName, String parentFolderId) async {
    try {
      final http.Response response;
      if (instanceType.toLowerCase() == 'angora') {
        response = await http.post(
          Uri.parse('$baseUrl/api/folders'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authToken,
            'x-portal': 'web',
            'x-customer-hostname': customerHostname,
          },
          body: jsonEncode({
            'name': folderName,
            'parent_id': parentFolderId,
          }),
        );
      } else {
        response = await http.post(
          Uri.parse('$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$parentFolderId/children'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authToken,
          },
          body: jsonEncode({
            'name': folderName,
            'nodeType': 'cm:folder',
          }),
        );
      }

      if (!context.mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Folder created successfully'),
            backgroundColor: EVColors.successGreen,
          ),
        );
        await onFolderCreated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create folder: ${response.body}'),
            backgroundColor: EVColors.statusError,
          ),
        );
      }
    } catch (e) {
      EVLogger.error('Error creating folder', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: EVColors.statusError,
          ),
        );
      }
    }
  }
}
