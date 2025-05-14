import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/upload_progress.dart';

/// A widget that displays a list of files being uploaded with their progress
class FileUploadProgressList extends StatelessWidget {
  final List<UploadProgress> uploadProgresses;
  final Function(String)? onCancelUpload;

  const FileUploadProgressList({
    super.key,
    required this.uploadProgresses,
    this.onCancelUpload,
  });

  @override
  Widget build(BuildContext context) {
    if (uploadProgresses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: EVColors.cardBackground,
        elevation: 2,
        shadowColor: EVColors.cardShadow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EVColors.buttonBackground.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upload_file, color: EVColors.buttonBackground),
                  const SizedBox(width: 8),
                  Text(
                    'Uploading ${uploadProgresses.length} ${uploadProgresses.length == 1 ? 'file' : 'files'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: EVColors.buttonBackground,
                    ),
                  ),
                ],
              ),
            ),            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: uploadProgresses.length,
                itemBuilder: (context, index) {
                  final progress = uploadProgresses[index];
                  return _UploadProgressItem(
                    progress: progress,
                    onCancel: onCancelUpload != null 
                        ? () => onCancelUpload!(progress.id)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadProgressItem extends StatelessWidget {
  final UploadProgress progress;
  final VoidCallback? onCancel;

  const _UploadProgressItem({
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (!progress.isComplete && onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onCancel,
                  tooltip: 'Cancel upload',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress.isComplete ? Colors.green : EVColors.infoBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${(progress.progress * 100).toInt()}%',
                style: TextStyle(
                  color: progress.isComplete ? Colors.green : EVColors.infoBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (progress.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                progress.error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 