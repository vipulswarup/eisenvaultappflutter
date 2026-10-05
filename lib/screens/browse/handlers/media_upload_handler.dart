import 'dart:io' show Platform;
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/upload/upload_service_factory.dart';
import 'package:eisenvaultappflutter/services/permission_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Handles camera, gallery, and document-scan uploads from the browse screen.
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
      final hasCameraPermission =
          await PermissionService.checkCameraPermission();
      if (!hasCameraPermission) {
        if (!context.mounted) return;
        final granted = await PermissionService.requestCameraPermission(
          context,
        );
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

  /// Scan a document with VisionKit (iOS) or Play Services document scanner
  /// (Android, with the plugin's fallback cropper) and upload the result.
  Future<void> scanDocumentAndUpload() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    if (_isIOSSimulator()) {
      _showSnackbar(
        'Document scanning is not supported on the iOS simulator. Please use a physical device.',
        EVColors.statusWarning,
      );
      return;
    }

    final options = await _showScanOptionsDialog();
    if (options == null || !context.mounted) return;

    try {
      final pictures = await CunningDocumentScanner.getPictures(
        asPdf: options.asPdf,
        scannerSource: ScannerSource.cameraAndGallery,
        androidScannerMode: AndroidScannerMode.full,
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: 0.85,
        ),
      );
      if (pictures == null || pictures.isEmpty || !context.mounted) return;

      final extension = options.asPdf ? '.pdf' : '.jpg';
      final fileName = await _getCustomFileName(extension);
      if (fileName == null || !context.mounted) return;

      await _uploadScannedFiles(pictures, fileName);
    } on CunningDocumentScannerException catch (e) {
      if (e.code == 'permission_denied') {
        _showSnackbar(
          'Camera permission is required to scan documents',
          EVColors.statusError,
        );
        return;
      }
      EVLogger.error('Error scanning document', e);
      _showSnackbar(
        'Error scanning document: ${e.message}',
        EVColors.statusError,
      );
    } catch (e) {
      EVLogger.error('Error scanning document', e);
      _showSnackbar('Error scanning document: $e', EVColors.statusError);
    } finally {
      try {
        await CunningDocumentScanner.cleanCache();
      } catch (_) {}
    }
  }

  Future<void> _uploadFiles(
    List<XFile> files, {
    required bool isCameraImage,
  }) async {
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
      final label =
          files.length == 1
              ? 'Image uploaded successfully'
              : 'Images uploaded successfully';
      _showSnackbar(label, EVColors.successGreen);
      await onUploadComplete();
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      _showSnackbar('Failed to upload: $e', EVColors.statusError);
    }
  }

  Future<void> _uploadScannedFiles(
    List<String> filePaths,
    String fileName,
  ) async {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var i = 0; i < filePaths.length; i++) {
        final filePath = filePaths[i];
        final extension =
            p.extension(filePath).isNotEmpty
                ? p.extension(filePath)
                : p.extension(fileName);
        final uploadName =
            filePaths.length == 1
                ? fileName
                : '${p.basenameWithoutExtension(fileName)}_page_${i + 1}$extension';
        await uploadService.uploadDocument(
          parentFolderId: parentFolderId,
          filePath: filePath,
          fileName: uploadName,
        );
      }

      if (context.mounted) Navigator.of(context).pop();
      final label =
          filePaths.length == 1
              ? 'Scanned document uploaded successfully'
              : '${filePaths.length} scanned documents uploaded successfully';
      _showSnackbar(label, EVColors.successGreen);
      await onUploadComplete();
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      _showSnackbar(
        'Failed to upload scanned documents: $e',
        EVColors.statusError,
      );
    }
  }

  Future<_ScanOptions?> _showScanOptionsDialog() async {
    var asPdf = false;

    return showDialog<_ScanOptions>(
      context: context,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: EVColors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    'Scan Options',
                    style: TextStyle(color: EVColors.textDefault),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Output Format:',
                          style: TextStyle(
                            color: EVColors.textDefault,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<bool>(
                        value: asPdf,
                        items: const [
                          DropdownMenuItem(
                            value: false,
                            child: Text('Images (JPG)'),
                          ),
                          DropdownMenuItem(value: true, child: Text('PDF')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => asPdf = value);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: EVColors.textSecondary),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EVColors.buttonBackground,
                        foregroundColor: EVColors.buttonForeground,
                      ),
                      onPressed:
                          () => Navigator.of(
                            dialogCtx,
                          ).pop(_ScanOptions(asPdf: asPdf)),
                      child: const Text('SCAN'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<String?> _getCustomFileName(String extension) async {
    var fileName = 'scanned_document_${DateTime.now().millisecondsSinceEpoch}';

    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: EVColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Name Your File',
              style: TextStyle(color: EVColors.textDefault),
            ),
            content: TextFormField(
              initialValue: fileName,
              autofocus: true,
              onChanged: (value) => fileName = value,
              decoration: InputDecoration(
                labelText: 'File Name',
                labelStyle: const TextStyle(color: EVColors.textFieldLabel),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: EVColors.textFieldBorder),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: EVColors.buttonBackground),
                ),
                suffixText: extension,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: EVColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EVColors.buttonBackground,
                  foregroundColor: EVColors.buttonForeground,
                ),
                onPressed: () {
                  final stem = fileName.trim();
                  if (stem.isEmpty) return;
                  Navigator.of(dialogCtx).pop('$stem$extension');
                },
                child: const Text('SAVE'),
              ),
            ],
          ),
    );
    return result;
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

class _ScanOptions {
  final bool asPdf;

  const _ScanOptions({required this.asPdf});
}
