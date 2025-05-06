import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/offline/download_progress.dart';

class DownloadProgressIndicator extends StatelessWidget {
  final DownloadProgress progress;
  final VoidCallback? onCancel;

  const DownloadProgressIndicator({
    Key? key,
    required this.progress,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EVColors.screenBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Downloading ${progress.fileName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onCancel,
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(EVColors.buttonBackground),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress.progress * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (progress.totalFiles > 1) ...[
            const SizedBox(height: 4),
            Text(
              'File ${progress.currentFileIndex} of ${progress.totalFiles}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}