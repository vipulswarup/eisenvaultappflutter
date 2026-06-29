import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:in_app_file_view/in_app_file_view.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppleOfficeFilePreview extends StatefulWidget {
  final Uint8List bytes;
  final String fileName;
  final VoidCallback? onOpenExternally;

  const AppleOfficeFilePreview({
    super.key,
    required this.bytes,
    required this.fileName,
    this.onOpenExternally,
  });

  @override
  State<AppleOfficeFilePreview> createState() => _AppleOfficeFilePreviewState();
}

class _AppleOfficeFilePreviewState extends State<AppleOfficeFilePreview> {
  FileViewController? _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prepareController();
  }

  Future<void> _prepareController() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final previewDir = Directory(p.join(cacheDir.path, 'previews'));
      if (!await previewDir.exists()) {
        await previewDir.create(recursive: true);
      }

      final safeFileName =
          p.basename(widget.fileName).replaceAll(RegExp(r'[^\w\s\.\-]'), '_');
      final file = File(p.join(previewDir.path, safeFileName));
      await file.writeAsBytes(widget.bytes, flush: true);

      if (!mounted) return;
      setState(() {
        _controller = FileViewController.file(
          file,
          customSavedFileName: p.basenameWithoutExtension(safeFileName),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildError(context, 'Could not prepare file for preview.');
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading preview...'),
          ],
        ),
      );
    }

    return FileView(
      controller: controller,
      progressColor: EVColors.palettePrimary,
      nonExistentWidget: _buildError(context, 'Could not load preview.'),
      unSupportedFileTypeWidget:
          _buildError(context, 'This file type is not supported on iOS.'),
      unSupportedPlatformWidget:
          _buildError(context, 'Preview is only available on iOS.'),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: EVColors.errorRed),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (widget.onOpenExternally != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onOpenExternally,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in External Application'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
