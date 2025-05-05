import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class DownloadProgressIndicator extends StatelessWidget {
  const DownloadProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    EVLogger.debug('DownloadProgressIndicator: build called');
    return Consumer<DownloadManager>(
      builder: (context, downloadManager, child) {
        EVLogger.debug('Indicator: DownloadManager instance', {'hash': downloadManager.hashCode});
        final progress = downloadManager.currentProgress;
        if (progress == null) {
          EVLogger.debug('DownloadProgressIndicator: No progress to show');
          return const SizedBox.shrink();
        }
        EVLogger.debug('DownloadProgressIndicator: Showing progress', {
          'fileName': progress.fileName,
          'progress': progress.progress,
          'totalFiles': progress.totalFiles,
          'currentFileIndex': progress.currentFileIndex
        });
        return Card(
          elevation: 4,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Downloading ${progress.fileName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      value: progress.progress,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress.progress * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (progress.totalFiles > 1)
                    Text(
                      'File ${progress.currentFileIndex} of ${progress.totalFiles}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} 