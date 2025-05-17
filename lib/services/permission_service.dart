import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> checkMediaPermissions() async {
    if (await Permission.storage.isGranted) {
      return true;
    }
    return false;
  }

  static Future<bool> requestMediaPermissions(BuildContext context) async {
    final status = await Permission.storage.request();
    
    if (status.isGranted) {
      return true;
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to upload documents'),
          ),
        );
      }
      return false;
    }
  }

  static Future<bool> checkCameraPermission() async {
    if (await Permission.camera.isGranted) {
      return true;
    }
    return false;
  }

  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    
    if (status.isGranted) {
      return true;
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to scan documents'),
          ),
        );
      }
      return false;
    }
  }
} 