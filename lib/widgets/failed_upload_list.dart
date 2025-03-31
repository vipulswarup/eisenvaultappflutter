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
    Key? key,
    required this.failedFiles,
    required this.isUploading,
    required this.onRetryFile,
    required this.onRetryAll,
  }) : super(key: key);
  
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
                color: Colors.red,
              ),
            ),
            ElevatedButton.icon(
              onPressed: isUploading ? null : onRetryAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
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
                color: Colors.red[50],
                child: ExpansionTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
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
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          // Show file ID for debugging purposes
                          if (file.id != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'File ID: ${file.id}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: isUploading ? null : () => onRetryFile(file),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
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