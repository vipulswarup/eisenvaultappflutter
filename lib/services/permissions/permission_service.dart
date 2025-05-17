import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

abstract class PermissionService {
  /// Checks if a specific permission exists for a node
  Future<bool> hasPermission(String nodeId, String permission);
  
  /// Get all permissions for a specific node
  Future<List<String>?> getPermissions(String nodeId);
  
  /// Extract permissions from a browse item
  /// If permissions data is not in the item, fetch it from the API
  Future<List<String>?> extractPermissionsFromItem(Map<String, dynamic> item);
  
  /// Clear any cached permissions
  void clearCache();

  static Future<bool> requestMediaPermissions(BuildContext context) async {
    // Request each permission individually
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    final audio = await Permission.audio.request();

    // Check if any permission was denied
    if (photos.isDenied || videos.isDenied || audio.isDenied) {
      // Show dialog explaining why permissions are needed
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permissions Required'),
            content: const Text(
              'EisenVault needs access to your media files to allow you to upload documents and images. '
              'Please grant these permissions to use all features of the app.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    return true;
  }

  static Future<bool> checkMediaPermissions() async {
    final photos = await Permission.photos.status;
    final videos = await Permission.videos.status;
    final audio = await Permission.audio.status;

    return photos.isGranted && videos.isGranted && audio.isGranted;
  }
}
