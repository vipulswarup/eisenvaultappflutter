import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/services/upload/batch_upload_manager.dart';

class FailedUploadList extends StatelessWidget {
  final List<UploadFileItem> failedFiles;
  final bool isUploading;
  final Function(UploadFileItem) onRetryFile;
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