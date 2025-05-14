import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/models/upload/batch_upload_models.dart';

/// Displays a list of file upload progress items
/// 
/// This widget renders a scrollable list of files being uploaded,
/// showing their current status and progress.
class FileUploadProgressList extends StatelessWidget {
  /// List of file upload progress objects to display
  final List<FileUploadProgress> fileProgresses;
  
  /// Whether uploads are currently in progress
  final bool isUploading;
  
  /// Optional callback for when an item is tapped
  final Function(FileUploadProgress)? onItemTap;
  
  const FileUploadProgressList({
    super.key,
    required this.fileProgresses,
    this.isUploading = false,
    this.onItemTap,
  });
  
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
          onTap: onItemTap != null ? () => onItemTap!(progress) : null,
        );
      },
    );
  }
}

/// Displays progress information for a single file upload
class FileUploadProgressItem extends StatelessWidget {
  /// Progress data for this file
  final FileUploadProgress progress;
  
  /// Whether uploads are currently in progress
  final bool isUploading;
  
  /// Optional callback for when this item is tapped
  final VoidCallback? onTap;
  
  const FileUploadProgressItem({
    super.key,
    required this.progress,
    this.isUploading = false,
    this.onTap,
  });
  
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
      child: InkWell(
        onTap: onTap,
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
              // Show additional information for debugging purposes in development
              if (progress.status == FileUploadStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'File ID: ${progress.fileId}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Convert status code to user-friendly text
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
