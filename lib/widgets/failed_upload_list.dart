import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/models/upload/batch_upload_models.dart';

/// Displays a list of files that failed to upload
/// 
/// This widget renders a list of failed uploads with
/// error details and retry options.
class FailedUploadList extends StatelessWidget {
  /// List of files that failed to upload
  final List<UploadFileItem> failedFiles;
  
  /// Whether uploads are currently in progress
  final bool isUploading;
  
  /// Callback for retrying a single file
  final Function(UploadFileItem) onRetryFile;
  
  /// Callback for retrying all failed files
  final VoidCallback onRetryAll;
  
  const FailedUploadList({
    super.key,
    required this.failedFiles,
    required this.isUploading,
    required this.onRetryFile,
    required this.onRetryAll,
  });
  
  @override
  Widget build(BuildContext context) {

    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Failed Files (${failedFiles.length}):',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: EVColors.errorRed,
              ),
            ),
            ElevatedButton.icon(
              onPressed: isUploading ? null : onRetryAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EVColors.warningOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: failedFiles.length,
            itemBuilder: (context, index) {
              final file = failedFiles[index];
              return Card(
                color: EVColors.statusErrorBackground,
                child: ExpansionTile(
                  leading: const Icon(Icons.error_outline, color: EVColors.errorRed),
                  title: Text(file.name),
                  subtitle: const Text('Failed to upload'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Error details:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            file.errorMessage ?? 'Unknown error',
                            style: const TextStyle(color: EVColors.errorRed),
                          ),
                          const SizedBox(height: 8),
                          // Show file ID for debugging purposes
                          if (file.id != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'File ID: ${file.id}',
                                style: TextStyle(color: EVColors.textGrey, fontSize: 12),
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: isUploading ? null : () => onRetryFile(file),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: EVColors.warningOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}