import 'package:flutter/material.dart';

/// Widget displayed when a folder is empty
class EmptyFolderView extends StatelessWidget {
  final VoidCallback? onUpload;

  const EmptyFolderView({
    super.key,
    this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'This folder is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          if (onUpload != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Files'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
