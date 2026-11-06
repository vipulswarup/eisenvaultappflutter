import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../constants/colors.dart';
import '../models/upload/batch_upload_models.dart';
import '../services/upload/batch_upload_manager.dart';
import '../services/upload/upload_folder_resolver.dart';
import '../services/upload/upload_selection.dart';
import '../services/upload/upload_service_factory.dart';
import '../utils/logger.dart';
import '../widgets/scan_dialog.dart';
import '../widgets/file_type_icon.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String repositoryType;
  final String parentFolderId;
  final String baseUrl;
  final String authToken;

  const DocumentUploadScreen({
    super.key,
    required this.repositoryType,
    required this.parentFolderId,
    required this.baseUrl,
    required this.authToken,
  });

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final List<UploadFileItem> _selectedFiles = [];
  final List<String> _selectionWarnings = [];
  final List<Uint8List> _bookmarks = [];
  final Map<String, FileUploadProgress> _fileProgress = {};
  final List<UploadFileItem> _failedFiles = [];
  bool _isUploading = false;
  bool _isSelecting = false;
  bool _dragging = false;
  BatchUploadProgress? _batchProgress;
  late final UploadFolderResolver _folderResolver;
  bool get _desktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
  bool get _busy => _isUploading || _isSelecting;

  @override
  void initState() {
    super.initState();
    _folderResolver = UploadFolderResolver(
      repositoryType: widget.repositoryType,
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      parentFolderId: widget.parentFolderId,
    );
  }

  Future<void> _pickFiles() => _select(() async => openFiles());
  Future<void> _pickFolder() => _select(() async {
    final path = await getDirectoryPath();
    return path == null ? <XFile>[] : [XFile(path)];
  });

  Future<void> _select(Future<List<XFile>> Function() choose) async {
    if (_busy) return;
    setState(() {
      _isSelecting = true;
      _dragging = false;
    });
    try {
      final files = await choose();
      if (!mounted) return;
      // A sandboxed macOS drop may require access beyond the drag callback.
      for (final file in files) {
        if (file is DropItem && file.extraAppleBookmark?.isNotEmpty == true) {
          final bookmark = file.extraAppleBookmark!;
          final granted = await DesktopDrop.instance
              .startAccessingSecurityScopedResource(bookmark: bookmark);
          if (granted) {
            if (!mounted) {
              await DesktopDrop.instance.stopAccessingSecurityScopedResource(
                bookmark: bookmark,
              );
              return;
            }
            _bookmarks.add(bookmark);
          }
        }
      }
      final UploadSelection selection;
      if (kIsWeb) {
        final items = <UploadFileItem>[];
        for (final file in files) {
          items.add(
            UploadFileItem(name: file.name, bytes: await file.readAsBytes()),
          );
        }
        selection = UploadSelection(items, []);
      } else {
        selection = await UploadSelectionScanner().scan(
          files.map((f) => f.path).toList(),
        );
      }
      if (!mounted) return;
      _addSelection(selection);
    } catch (e) {
      EVLogger.error('Error selecting upload items', {'error': e.toString()});
      if (mounted) _message('Could not select items: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  void _addSelection(UploadSelection selection) {
    setState(() {
      _selectionWarnings.addAll(selection.skipped);
      final rejectedDirectories = <String>[];
      for (final item in selection.items) {
        if (rejectedDirectories.any(
          (dir) => item.destinationPath.startsWith('$dir/'),
        )) {
          continue;
        }
        final matches = _selectedFiles.where(
          (f) =>
              f.destinationPath.toLowerCase() ==
              item.destinationPath.toLowerCase(),
        );
        if (matches.isNotEmpty) {
          if (matches.first.path != item.path) {
            _selectionWarnings.add(
              '${item.destinationPath}: another item already uses this destination',
            );
            if (item.isDirectory) {
              rejectedDirectories.add(item.destinationPath);
            }
          }
          continue;
        }
        _selectedFiles.add(item);
      }
    });
  }

  Future<void> _scan() async {
    if (_busy) return;
    final pdfPath = await showScanDialog(context);
    if (pdfPath == null || !mounted) return;
    await _select(() async => [XFile(pdfPath)]);
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? EVColors.errorRed : EVColors.successGreen,
      ),
    );
  }

  Future<void> _uploadFiles([List<UploadFileItem>? retry]) async {
    if (_busy) return;
    final files = List<UploadFileItem>.of(retry ?? _selectedFiles);
    if (files.isEmpty) return;
    setState(() {
      _isUploading = true;
      _fileProgress.clear();
      _batchProgress = null;
    });
    try {
      final manager = BatchUploadManager(
        onBatchProgressUpdate: (progress) {
          if (mounted) setState(() => _batchProgress = progress);
        },
        onFileProgressUpdate: (progress) {
          if (mounted) {
            setState(() => _fileProgress[progress.fileName] = progress);
          }
        },
      );
      final result = await manager.uploadBatch(
        files: files,
        uploadService: UploadServiceFactory.getService(
          instanceType: widget.repositoryType,
          baseUrl: widget.baseUrl,
          authToken: widget.authToken,
        ),
        parentFolderId: widget.parentFolderId,
        resolveFolder: _folderResolver.resolve,
      );
      if (!mounted) return;
      setState(() {
        final uploaded =
            result.successful.map((f) => f.destinationPath).toSet();
        _selectedFiles.removeWhere((f) => uploaded.contains(f.destinationPath));
        final attempted = files.map((f) => f.destinationPath).toSet();
        _failedFiles.removeWhere((f) => attempted.contains(f.destinationPath));
        _failedFiles.addAll(result.failed);
      });
      _message(
        '${result.successCount} items uploaded, ${result.failureCount} failed.',
        error: result.failed.isNotEmpty,
      );
      // Stay on the review screen so results are visible and more items can be added.
    } catch (e) {
      if (mounted) _message('Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _remove(UploadFileItem item) {
    setState(() {
      bool removed(UploadFileItem f) =>
          f.destinationPath == item.destinationPath ||
          (item.isDirectory &&
              f.destinationPath.startsWith('${item.destinationPath}/'));
      _selectedFiles.removeWhere(removed);
      _failedFiles.removeWhere(removed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repository: ${widget.repositoryType.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_desktop)
            Container(
              key: const Key('upload-drop-zone'),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:
                    _dragging
                        ? EVColors.buttonBackground.withValues(alpha: .15)
                        : EVColors.cardBackground,
                border: Border.all(
                  color:
                      _dragging
                          ? EVColors.buttonBackground
                          : EVColors.textSecondary,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.drive_folder_upload_outlined, size: 32),
                  Text(
                    _dragging
                        ? 'Drop to add to upload queue'
                        : 'Drop files or folders here',
                  ),
                  const Text(
                    'Review before uploading. Folder structure is preserved.',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _busy ? null : _pickFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Select Files'),
              ),
              if (_desktop)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Select Folder'),
                ),
              if (_desktop)
                OutlinedButton.icon(
                  key: const Key('upload-scan-button'),
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan'),
                ),
            ],
          ),
          if (_isSelecting) const LinearProgressIndicator(),
          if (_selectionWarnings.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 90),
              child: SingleChildScrollView(
                child: Text(
                  'Skipped items:\n${_selectionWarnings.join('\n')}',
                  style: const TextStyle(color: EVColors.errorRed),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('Upload queue (${_selectedFiles.length} items)'),
          Expanded(
            child:
                _selectedFiles.isEmpty
                    ? const Center(child: Text('No items selected'))
                    : ListView.builder(
                      itemCount: _selectedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _selectedFiles[index];
                        final errors = _failedFiles.where(
                          (f) => f.destinationPath == file.destinationPath,
                        );
                        final progress = _fileProgress[file.destinationPath];
                        return ListTile(
                          leading:
                              file.isDirectory
                                  ? const Icon(Icons.folder)
                                  : FileTypeIcon(
                                    fileName: file.name,
                                    iconSize: 24,
                                  ),
                          title: Text(file.destinationPath),
                          subtitle: Text(
                            errors.isNotEmpty
                                ? errors.first.errorMessage!
                                : progress?.status ??
                                    (file.isDirectory
                                        ? 'Folder'
                                        : 'Ready to upload'),
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove from queue',
                            icon: const Icon(Icons.close),
                            onPressed: _busy ? null : () => _remove(file),
                          ),
                        );
                      },
                    ),
          ),
          if (_batchProgress != null) ...[
            LinearProgressIndicator(
              value:
                  _batchProgress!.completedFiles / _batchProgress!.totalFiles,
            ),
            Text(
              '${_batchProgress!.completedFiles} of ${_batchProgress!.totalFiles} items complete; '
              '${_batchProgress!.successfulFiles} successful, ${_batchProgress!.failedFiles} failed',
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed:
                    _busy || _selectedFiles.isEmpty
                        ? null
                        : () => _uploadFiles(),
                icon: const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? 'Uploading…' : 'Upload All Items'),
              ),
              if (_failedFiles.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _uploadFiles(_failedFiles),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Failed Items'),
                ),
            ],
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload Documents'),
          backgroundColor: EVColors.appBarBackground,
          foregroundColor: EVColors.appBarForeground,
        ),
        body:
            _desktop
                ? DropTarget(
                  enable: !_busy,
                  onDragEntered: (_) => setState(() => _dragging = true),
                  onDragExited: (_) => setState(() => _dragging = false),
                  onDragDone: (details) => _select(() async => details.files),
                  child: content,
                )
                : content,
      ),
    );
  }

  @override
  void dispose() {
    for (final bookmark in _bookmarks) {
      unawaited(
        DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark,
        ),
      );
    }
    _folderResolver.dispose();
    super.dispose();
  }
}
