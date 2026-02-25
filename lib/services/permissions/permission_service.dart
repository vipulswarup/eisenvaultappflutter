import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return true;
      }
    }
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    final audio = await Permission.audio.request();
    if (photos.isDenied || videos.isDenied || audio.isDenied) {
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
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return true;
      }
    }
    final photos = await Permission.photos.status;
    final videos = await Permission.videos.status;
    final audio = await Permission.audio.status;
    return photos.isGranted && videos.isGranted && audio.isGranted;
  }
}
