import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class GenericFilePreviewScreen extends StatelessWidget {
  final String title;
  final dynamic fileContent; // Path (String) or bytes (Uint8List)
  final FileType fileType;

  const GenericFilePreviewScreen({
    Key? key,
    required this.title,
    required this.fileContent,
    required this.fileType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Action to share the file
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareFile(context),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // File type icon
              Icon(
                _getFileTypeIcon(),
                size: 80,
                color: _getFileTypeColor(),
              ),
              const SizedBox(height: 24),
              
              // File name
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // File type
              Text(
                'File Type: ${FileTypeUtils.getFileTypeString(fileType)}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              
              // Action buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open with External App'),
                onPressed: () => _openWithExternalApp(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileTypeIcon() {
    switch (fileType) {
      case FileType.spreadsheet:
        return Icons.table_chart;
      case FileType.document:
        return Icons.description;
      case FileType.presentation:
        return Icons.present_to_all;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor() {
    switch (fileType) {
      case FileType.spreadsheet:
        return Colors.green;
      case FileType.document:
        return Colors.blue;
      case FileType.presentation:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openWithExternalApp(BuildContext context) async {
    try {
      if (kIsWeb) {
        // For web, we can't directly open files with external apps
        // We could implement a download function here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download functionality for web is not yet implemented')),
        );
        return;
      }
      
      if (fileContent is String) {
        final filePath = fileContent as String;
        final fileUri = Uri.file(filePath);
        
        if (await canLaunchUrl(fileUri)) {
          await launchUrl(fileUri);
        } else {
          throw Exception('Could not launch $fileUri');
        }
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
}
