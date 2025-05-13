import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/utils/file_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';


class GenericFilePreviewScreen extends StatelessWidget {
  final String title;
  final dynamic fileContent; // Can be a File path (String) or bytes (Uint8List)
  final String mimeType;

  const GenericFilePreviewScreen({
    Key? key,
    required this.title,
    required this.fileContent,
    required this.mimeType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in external app',
            onPressed: () => _openWithExternalApp(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share file',
            onPressed: () => _shareFile(context),
          ),
        ],
      ),
      body: _buildPreview(context),
    );
  }

  Widget _buildPreview(BuildContext context) {
    try {
      // Show external app button for any unsupported file type
      if (!FileTypeUtils.isPreviewSupported(title)) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getFileTypeIcon(), size: 64),
              const SizedBox(height: 16),
              Text('This file type is best viewed in an external application.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center),
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
        );
      }
      if (fileContent is Uint8List) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.file_present, size: 64),
              const SizedBox(height: 16),
              Text('File Type: ${FileUtils.getFileTypeFromMimeType(mimeType)}'),
              const SizedBox(height: 8),
              Text('Size: ${(fileContent as Uint8List).length} bytes'),
              const SizedBox(height: 16),
              const Text('Preview not available for this file type'),
            ],
          ),
        );
      } else if (fileContent is String) {
        final file = File(fileContent as String);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.file_present, size: 64),
              const SizedBox(height: 16),
              Text('File Type: ${FileUtils.getFileTypeFromMimeType(mimeType)}'),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: file.length(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text('Size: ${snapshot.data} bytes');
                  }
                  return const Text('Calculating size...');
                },
              ),
              const SizedBox(height: 16),
              const Text('Preview not available for this file type'),
            ],
          ),
        );
      }

      EVLogger.error('Unsupported file content type', {
        'type': fileContent.runtimeType.toString()
      });
      
      return const Center(
        child: Text('Error: File content format not supported'),
      );
    } catch (e) {
      EVLogger.error('Error displaying file preview', e);
      return Center(
        child: Text('Error displaying file preview: ${e.toString()}'),
      );
    }
  }

  IconData _getFileTypeIcon() {
    switch (FileTypeUtils.getFileTypeFromMimeType(mimeType)) {
      case FileType.spreadsheet:
        return Icons.table_chart;
      case FileType.officeDocument:
      case FileType.openDocument:
        return Icons.description;
      case FileType.text:
        return Icons.text_snippet;
      case FileType.pdf:
        return Icons.picture_as_pdf;
      case FileType.image:
        return Icons.image;
      case FileType.video:
        return Icons.video_file;
      case FileType.audio:
        return Icons.audio_file;
      case FileType.cad:
        return Icons.architecture;
      case FileType.vector:
        return Icons.brush;
      case FileType.other:
      case FileType.unknown:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor() {
    switch (FileTypeUtils.getFileTypeFromMimeType(mimeType)) {
      case FileType.spreadsheet:
        return Colors.green;
      case FileType.officeDocument:
      case FileType.openDocument:
        return Colors.blue;
      case FileType.text:
        return Colors.orange;
      case FileType.pdf:
        return Colors.red;
      case FileType.image:
        return Colors.purple;
      case FileType.video:
        return Colors.indigo;
      case FileType.audio:
        return Colors.teal;
      case FileType.cad:
        return Colors.brown;
      case FileType.vector:
        return Colors.pink;
      case FileType.other:
      case FileType.unknown:
        return Colors.grey;
    }
  }

  Future<void> _openWithExternalApp(BuildContext context) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download functionality for web is not yet implemented')),
        );
        return;
      }
    
      String filePath;
      if (fileContent is String) {
        filePath = fileContent as String;
      } else if (fileContent is Uint8List) {
        // Handle bytes case - save to temp file first
        final bytes = fileContent as Uint8List;
        final tempDir = await getTemporaryDirectory();
        // Create a filename without special characters that could cause issues
        final safeFileName = title.replaceAll(RegExp(r'[^\w\s\.]'), '_');
        final file = File('${tempDir.path}/$safeFileName');
        await file.writeAsBytes(bytes);
        filePath = file.path;
      } else {
        throw Exception('Unsupported file content type');
      }
    
      // Use open_file package for better file handling
      final result = await OpenFile.open(filePath);
    
      if (result.type != ResultType.done) {
        EVLogger.error('Error opening file with external app', result.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: ${result.message}')),
        );
      }
    } catch (e) {
      EVLogger.error('Error opening file with external app', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: ${e.toString()}')),
      );
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing is not available on web')),
        );
        return;
      }
      
      if (fileContent is String) {
        await Share.shareXFiles([XFile(fileContent as String)], text: 'Sharing file: $title');
      } else {
        // If we have bytes instead of a file path, save to temp file first
        final bytes = fileContent as Uint8List;
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$title');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Sharing file: $title');
      }
    } catch (e) {
      EVLogger.error('Error sharing file', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: ${e.toString()}')),
      );
    }
  }

  void _handleFileType(FileType fileType) {
    switch (fileType) {
      case FileType.pdf:
        // Handle PDF
        break;
      case FileType.image:
        // Handle image
        break;
      case FileType.officeDocument:
        // Handle office documents
        break;
      case FileType.openDocument:
        // Handle open documents
        break;
      case FileType.text:
        // Handle text files
        break;
      case FileType.spreadsheet:
        // Handle spreadsheets
        break;
      case FileType.cad:
        // Handle CAD files
        break;
      case FileType.vector:
        // Handle vector files
        break;
      case FileType.video:
        // Handle video files
        break;
      case FileType.audio:
        // Handle audio files
        break;
      case FileType.other:
      case FileType.unknown:
        // Handle unknown files
        break;
    }
  }
}
