import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/utils/share_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:eisenvaultappflutter/widgets/file_type_icon.dart';

class UnsupportedFilePreview extends StatelessWidget {
  final String fileName;
  final FileType fileType;
  final String filePath;
  final String? mimeType;

  const UnsupportedFilePreview({
    super.key,
    required this.fileName,
    required this.fileType,
    required this.filePath,
    this.mimeType,
  });

  Future<void> _openInExternalApp(BuildContext context) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening file: ${result.message}'),
              backgroundColor: EVColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: EVColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      await ShareUtils.shareXFiles(
        context,
        files: [XFile(filePath)],
        text: 'Sharing $fileName',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            backgroundColor: EVColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FileTypeIcon(
              fileName: fileName,
              showBackground: false,
              iconSize: 64,
            ),
            const SizedBox(height: 16),
            Text(
              fileName,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              FileTypeUtils.getFileTypeName(fileType),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in External App'),
              onPressed: () => _openInExternalApp(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share File'),
              onPressed: () => _shareFile(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Preview not available in the app',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 