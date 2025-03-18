import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/services/upload/batch_upload_manager.dart';

class FileUploadProgressList extends StatelessWidget {
  final List<FileUploadProgress> fileProgresses;
  final bool isUploading;
  
  const FileUploadProgressList({
    Key? key,
    required this.fileProgresses,
    this.isUploading = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: fileProgresses.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final progress = fileProgresses[index];
        return FileUploadProgressItem(
          progress: progress,
          isUploading: isUploading,
        );
      },
    );
  }
}

class FileUploadProgressItem extends StatelessWidget {
  final FileUploadProgress progress;
  final bool isUploading;
  
  const FileUploadProgressItem({
    Key? key,
    required this.progress,
    this.isUploading = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Determine icon and color based on status
    IconData statusIcon;
    Color statusColor;
    
    switch (progress.status) {
      case FileUploadStatus.waiting:
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.grey;
        break;
      case FileUploadStatus.inProgress:
        statusIcon = Icons.cloud_upload;
        statusColor = Colors.blue;
        break;
      case FileUploadStatus.success:
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case FileUploadStatus.failed:
        statusIcon = Icons.error;
        statusColor = Colors.red;
        break;
      default:
        statusIcon = Icons.help;
        statusColor = Colors.grey;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    progress.fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progress.status == FileUploadStatus.inProgress && isUploading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.percentComplete / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getStatusText(progress.status),
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
                Text(
                  '${progress.percentComplete.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case FileUploadStatus.waiting:
        return 'Waiting';
      case FileUploadStatus.inProgress:
        return 'Uploading';
      case FileUploadStatus.success:
        return 'Completed';
      case FileUploadStatus.failed:
        return 'Failed';
      default:
        return 'Unknown';
    }
  }
}
