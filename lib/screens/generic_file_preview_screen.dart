import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:eisenvaultappflutter/widgets/file_type_icon.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/utils/share_utils.dart';
import 'package:eisenvaultappflutter/widgets/apple_office_file_preview.dart';
import 'package:eisenvaultappflutter/widgets/office_document_preview.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GenericFilePreviewScreen extends StatefulWidget {
  final String title;
  final dynamic fileContent;
  final String mimeType;

  const GenericFilePreviewScreen({
    super.key,
    required this.title,
    required this.fileContent,
    required this.mimeType,
  });

  @override
  State<GenericFilePreviewScreen> createState() =>
      _GenericFilePreviewScreenState();
}

class _GenericFilePreviewScreenState extends State<GenericFilePreviewScreen> {
  String? _resolvedFilePath;
  late final Future<Uint8List> _fileBytesFuture = _resolveFileBytes();

  bool get _usesMicrosoftViewer =>
      FileTypeUtils.usesMicrosoftViewer(widget.title);

  bool get _usesAppleInAppFileView =>
      FileTypeUtils.usesAppleInAppFileView(widget.title);

  bool get _usesOfficeDocumentPreview =>
      _usesAppleInAppFileView || _usesMicrosoftViewer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in external app',
              onPressed: () => _openWithExternalApp(context),
            ),
          Builder(
            builder: (buttonContext) => IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share file',
              onPressed: () => _shareFile(buttonContext),
            ),
          ),
        ],
      ),
      body: _buildPreview(context),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_usesOfficeDocumentPreview) {
      return _buildOfficeDocumentBody(context);
    }

    if (!FileTypeUtils.isPreviewSupported(widget.title)) {
      return _buildExternalAppPrompt(context);
    }

    return _buildUnsupportedPreviewBody(context);
  }

  Widget _buildOfficeDocumentBody(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _fileBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
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

        if (snapshot.hasError || !snapshot.hasData) {
          EVLogger.error('Error loading Office document preview', snapshot.error);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: EVColors.errorRed),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load preview.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in External Application'),
                    onPressed: () => _openWithExternalApp(context),
                  ),
                ],
              ),
            ),
          );
        }

        if (_usesAppleInAppFileView) {
          return AppleOfficeFilePreview(
            bytes: snapshot.data!,
            fileName: widget.title,
            onOpenExternally:
                kIsWeb ? null : () => _openWithExternalApp(context),
          );
        }

        return OfficeDocumentPreview(
          bytes: snapshot.data!,
          fileName: widget.title,
          onOpenExternally: kIsWeb ? null : () => _openWithExternalApp(context),
        );
      },
    );
  }

  Widget _buildExternalAppPrompt(BuildContext context) {
    final usesServerPreview = FileTypeUtils.usesServerPdfPreview(widget.title);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FileTypeIcon(
              fileName: widget.title,
              showBackground: false,
              iconSize: 64,
            ),
            const SizedBox(height: 16),
            Text(
              usesServerPreview
                  ? 'In-app preview is not available for this legacy Office format. Open it in an external application instead.'
                  : 'This file type is best viewed in an external application.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in External Application'),
            onPressed: () => _openWithExternalApp(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedPreviewBody(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _fileBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final size = snapshot.hasData ? snapshot.data!.length : null;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.file_present, size: 64),
              const SizedBox(height: 16),
              Text(
                'File Type: ${FileTypeUtils.getFileTypeString(FileTypeUtils.getFileType(widget.title))}',
              ),
              if (size != null) ...[
                const SizedBox(height: 8),
                Text('Size: $size bytes'),
              ],
              const SizedBox(height: 16),
              const Text('Preview not available for this file type'),
            ],
          ),
        );
      },
    );
  }

  Future<Uint8List> _resolveFileBytes() async {
    if (widget.fileContent is Uint8List) {
      return widget.fileContent as Uint8List;
    }
    if (widget.fileContent is List<int>) {
      return Uint8List.fromList(widget.fileContent as List<int>);
    }
    if (widget.fileContent is String) {
      final file = File(widget.fileContent as String);
      if (!await file.exists()) {
        throw Exception('File not found at path: ${file.path}');
      }
      return file.readAsBytes();
    }
    throw Exception(
      'Unsupported file content type: ${widget.fileContent.runtimeType}',
    );
  }

  Future<void> _openWithExternalApp(BuildContext context) async {
    try {
      if (kIsWeb) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download functionality for web is not yet implemented'),
            ),
          );
        }
        return;
      }

      final filePath = await _resolveFilePath();
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        EVLogger.error('Error opening file with external app', result.message);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      EVLogger.error('Error opening file with external app', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: ${e.toString()}')),
        );
      }
    }
  }

  Future<String> _resolveFilePath() async {
    if (_resolvedFilePath != null) {
      if (await File(_resolvedFilePath!).exists()) {
        return _resolvedFilePath!;
      }
      _resolvedFilePath = null;
    }

    if (widget.fileContent is String) {
      final existingPath = widget.fileContent as String;
      if (await File(existingPath).exists()) {
        _resolvedFilePath = existingPath;
        return existingPath;
      }
      throw Exception('File not found at path: $existingPath');
    }

    final bytes = await _resolveFileBytes();
    if (bytes.isEmpty) {
      throw Exception('File content is empty');
    }

    final cacheDir = await getApplicationCacheDirectory();
    final previewDir = Directory(p.join(cacheDir.path, 'previews'));
    if (!await previewDir.exists()) {
      await previewDir.create(recursive: true);
    }

    final safeFileName =
        p.basename(widget.title).replaceAll(RegExp(r'[^\w\s\.\-]'), '_');
    final file = File(p.join(previewDir.path, safeFileName));
    await file.writeAsBytes(bytes, flush: true);

    if (!await file.exists()) {
      throw Exception('Failed to write preview file to disk');
    }

    _resolvedFilePath = file.path;
    return file.path;
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing is not available on web')),
        );
        return;
      }

      final filePath = await _resolveFilePath();
      await ShareUtils.shareXFiles(
        context,
        files: [XFile(filePath)],
        text: 'Sharing file: ${widget.title}',
      );
    } catch (e) {
      EVLogger.error('Error sharing file', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: ${e.toString()}')),
        );
      }
    }
  }
}
