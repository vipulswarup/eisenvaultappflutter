import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/upload/upload_service_factory.dart';
import 'package:eisenvaultappflutter/services/permission_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Handles camera and gallery uploads from the browse screen.
class MediaUploadHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final String? Function() getCurrentFolderId;
  final Future<void> Function() onUploadComplete;

  MediaUploadHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.getCurrentFolderId,
    required this.onUploadComplete,
  });

  /// Take a picture with the camera and upload it.
  Future<void> takePictureAndUpload() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    // Detect iOS simulator
    if (_isIOSSimulator()) {
      _showSnackbar(
        'Camera is not supported on the iOS simulator. Please use the gallery option.',
        EVColors.statusWarning,
      );
      return;
    }

    final picker = ImagePicker();
    XFile? image;

    if (Platform.isAndroid) {
      final hasCameraPermission = await PermissionService.checkCameraPermission();
      if (!hasCameraPermission) {
        final granted = await PermissionService.requestCameraPermission(context);
        if (!granted) return;
      }
      image = await picker.pickImage(source: ImageSource.camera);
    } else if (Platform.isIOS) {
      image = await picker.pickImage(source: ImageSource.camera);
    }
    if (image == null) return;

    await _uploadFiles([image], isCameraImage: true);
  }

  /// Pick images from gallery and upload them.
  Future<void> uploadFromGallery() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isEmpty) return;
      await _uploadFiles(images, isCameraImage: false);
    } catch (e) {
      EVLogger.error('Error picking images from gallery', e);
      _showSnackbar('Failed to pick images: $e', EVColors.statusError);
    }
  }

  Future<void> _uploadFiles(List<XFile> files, {required bool isCameraImage}) async {
    final parentFolderId = getCurrentFolderId();
    if (parentFolderId == null) {
      _showSnackbar('No folder selected', EVColors.statusError);
      return;
    }

    final uploadService = UploadServiceFactory.getService(
      instanceType: instanceType,
      baseUrl: baseUrl,
      authToken: authToken,
    );

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (final file in files) {
        String uploadName = file.name;
        if (Platform.isIOS && uploadName.startsWith('image_picker_')) {
          uploadName = uploadName.replaceFirst(
            'image_picker_',
            isCameraImage ? 'ios_camera_' : 'ios_photo_',
          );
        }
        await uploadService.uploadDocument(
          parentFolderId: parentFolderId,
          filePath: file.path,
          fileName: uploadName,
        );
      }

      if (context.mounted) Navigator.of(context).pop();
      final label = files.length == 1 ? 'Image uploaded successfully' : 'Images uploaded successfully';
      _showSnackbar(label, EVColors.successGreen);
      await onUploadComplete();
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      _showSnackbar('Failed to upload: $e', EVColors.statusError);
    }
  }

  bool _isIOSSimulator() {
    try {
      return Platform.isIOS &&
          !Platform.isMacOS &&
          (Platform.environment['SIMULATOR_DEVICE_NAME'] != null);
    } catch (_) {
      return false;
    }
  }

  void _showSnackbar(String message, Color backgroundColor) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }
}
