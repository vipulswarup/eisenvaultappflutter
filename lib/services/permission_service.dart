import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> checkMediaPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      if (sdkVersion >= 33) {
        return true;
      }
      return await Permission.storage.isGranted;
    } else if (Platform.isIOS) {
      // iOS uses photos permission
      return await Permission.photos.isGranted;
    }
    return true;
  }

  static Future<bool> requestMediaPermissions(BuildContext context) async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      if (sdkVersion >= 33) {
        return true;
      }
      final status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to access files'),
          ),
        );
      }
      return false;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (status.isGranted) {
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo library permission is required to access files'),
            ),
          );
        }
        return false;
      }
    }
    return true;
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