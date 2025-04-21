import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/failed_upload.dart';

/// A widget that displays a list of failed uploads with retry options
class FailedUploadList extends StatelessWidget {
  final List<FailedUpload> failedUploads;
  final Function(FailedUpload) onRetry;
  final Function(FailedUpload) onRemove;

  const FailedUploadList({
    Key? key,
    required this.failedUploads,
    required this.onRetry,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (failedUploads.isEmpty) {
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
        child: Column(          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Failed Uploads (${failedUploads.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: failedUploads.length,
                itemBuilder: (context, index) {
                  final failedUpload = failedUploads[index];
                  return _FailedUploadItem(
                    failedUpload: failedUpload,
                    onRetry: () => onRetry(failedUpload),
                    onRemove: () => onRemove(failedUpload),
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

class _FailedUploadItem extends StatelessWidget {
  final FailedUpload failedUpload;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  const _FailedUploadItem({
    required this.failedUpload,
    required this.onRetry,
    required this.onRemove,
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
                  failedUpload.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: onRetry,
                tooltip: 'Retry upload',
                color: EVColors.buttonBackground,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onRemove,
                tooltip: 'Remove from list',
                color: Colors.red,
              ),
            ],
          ),
          if (failedUpload.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                failedUpload.error!,
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