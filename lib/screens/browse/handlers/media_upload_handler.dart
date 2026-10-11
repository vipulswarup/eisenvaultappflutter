import 'dart:io' show Platform, File;
import '../../../services/photos/photo_upload_settings.dart';
import '../../../services/photos/pending_camera_capture.dart';
import '../../../services/photos/photo_location_service.dart';
import '../../../services/photos/photo_geostamp_service.dart';
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
  static bool _recoveringCamera = false;
  final String cameraCaptureScope;
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final String? Function() getCurrentFolderId;
  final Future<void> Function() onUploadComplete;

  MediaUploadHandler({
    this.cameraCaptureScope = '',
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

    final destinationFolderId = getCurrentFolderId();
    if (destinationFolderId == null) {
      _showSnackbar('No folder selected', EVColors.statusError);
      return;
    }
    File? prepared;
    try {
      if (Platform.isAndroid) {
        final hasPermission = await PermissionService.checkCameraPermission();
        if (!hasPermission) {
          if (!context.mounted) return;
          if (!await PermissionService.requestCameraPermission(context)) return;
        }
      }
      var enabled = await PhotoUploadSettings().isGeostampEnabled();
      PhotoLocation? location;
      if (enabled) {
        final result = await _locateForPhoto();
        if (result.cancelled || !context.mounted) return;
        location = result.location;
        enabled = location != null;
      }
      if (!context.mounted) return;
      if (Platform.isAndroid) {
        await PendingCameraCapture(
          scope: cameraCaptureScope,
          folderId: destinationFolderId,
          geostampEnabled: enabled,
        ).save();
      }
      XFile? image;
      try {
        image = await ImagePicker().pickImage(source: ImageSource.camera);
      } finally {
        if (Platform.isAndroid) await PendingCameraCapture.clear();
      }
      final capturedImage = image;
      if (capturedImage == null || !context.mounted) return;
      if (enabled) {
        // Refresh on return: the user may have moved while the camera was open.
        final result = await _locateForPhoto();
        if (result.cancelled || !context.mounted) return;
        location = result.location;
        if (location != null) {
          while (context.mounted) {
            try {
              prepared = await _withPhotoProgress(
                () => PhotoGeostampService().prepare(
                  capturedImage.path,
                  location!,
                ),
              );
              break;
            } catch (_) {
              if (!context.mounted) return;
              final choice = await _geostampFallback(
                'The photo could not be geostamped. Its image format may not be supported.',
              );
              if (choice == null || choice == 'cancel') return;
              if (choice == 'without') break;
            }
          }
        }
      }
      if (!context.mounted) return;
      await _uploadCameraPhoto(
        prepared == null ? capturedImage : XFile(prepared.path),
        destinationFolderId,
      );
    } catch (_) {
      _showSnackbar(
        'Could not capture or prepare the photo. Please try again.',
        EVColors.statusError,
      );
    } finally {
      if (prepared != null) {
        try {
          await prepared.parent.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Android may restart the app while the external camera is active.
  Future<void> recoverInterruptedCameraUpload() async {
    if (!Platform.isAndroid || _recoveringCamera) return;
    _recoveringCamera = true;
    try {
      final pending = await PendingCameraCapture.read(cameraCaptureScope);
      if (pending == null) return;
      final result = await ImagePicker().retrieveLostData();
      await PendingCameraCapture.clear();
      if (!context.mounted || result.isEmpty) return;
      final files = result.files;
      if (files == null || files.isEmpty) {
        _showSnackbar(
          'The interrupted camera photo could not be recovered.',
          EVColors.statusWarning,
        );
        return;
      }
      final upload = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Recovered camera photo'),
              content: Text(
                pending.geostampEnabled
                    ? 'The app restarted while the camera was open. The capture location cannot be verified. Upload this photo without adding a geostamp to the originally selected folder?'
                    : 'Upload the recovered camera photo to the originally selected folder?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    pending.geostampEnabled
                        ? 'Upload without geostamp'
                        : 'Upload',
                  ),
                ),
              ],
            ),
      );
      if (upload == true && context.mounted) {
        await _uploadCameraPhoto(files.first, pending.folderId);
      }
    } catch (_) {
      _showSnackbar(
        'Could not recover the interrupted camera photo.',
        EVColors.statusWarning,
      );
    } finally {
      _recoveringCamera = false;
    }
  }

  Future<void> _uploadCameraPhoto(XFile photo, String folderId) async {
    while (context.mounted) {
      if (await _uploadFiles(
        [photo],
        isCameraImage: true,
        destinationFolderId: folderId,
      )) {
        return;
      }
      if (!context.mounted) return;
      final retry = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Photo upload failed'),
              content: const Text('Retry uploading the same prepared photo?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Retry'),
                ),
              ],
            ),
      );
      if (retry != true) return;
    }
  }

  Future<T> _withPhotoProgress<T>(Future<T> Function() action) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Expanded(child: Text('Preparing photo geostamp…')),
                ],
              ),
            ),
          ),
    );
    try {
      return await action();
    } finally {
      if (navigator.mounted) navigator.pop();
    }
  }

  Future<({PhotoLocation? location, bool cancelled})> _locateForPhoto() async {
    while (context.mounted) {
      try {
        final location = await _withPhotoProgress(
          () => PhotoLocationService().locate(),
        );
        return (location: location, cancelled: false);
      } catch (error) {
        if (!context.mounted) break;
        final message =
            error is PhotoLocationException
                ? error.message
                : 'A fresh location could not be obtained. Please check location access and try again.';
        final choice = await _geostampFallback(message);
        if (choice == 'without') return (location: null, cancelled: false);
        if (choice != 'retry') break;
      }
    }
    return (location: null, cancelled: true);
  }

  Future<String?> _geostampFallback(String message) => showDialog<String>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Geostamp unavailable'),
          content: Text(
            '$message\n\nYou can continue without adding a geostamp for this photo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'without'),
              child: const Text('Upload without geostamp'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'retry'),
              child: const Text('Retry'),
            ),
          ],
        ),
  );

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

  Future<bool> _uploadFiles(
    List<XFile> files, {
    required bool isCameraImage,
    String? destinationFolderId,
  }) async {
    final parentFolderId = destinationFolderId ?? getCurrentFolderId();
    if (parentFolderId == null) {
      _showSnackbar('No folder selected', EVColors.statusError);
      return false;
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
      if (isCameraImage) {
        // A refresh failure must not cause a duplicate upload on retry.
        try {
          await onUploadComplete();
        } catch (_) {}
      } else {
        await onUploadComplete();
      }
      return true;
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      _showSnackbar('Failed to upload: $e', EVColors.statusError);
      return false;
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
