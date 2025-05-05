import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class DownloadProgressIndicator extends StatelessWidget {
  const DownloadProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    
    return Consumer<DownloadManager>(
      builder: (context, downloadManager, child) {
        
        final progress = downloadManager.currentProgress;
        if (progress == null) return const SizedBox.shrink();

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
                      'File ${progress.currentFileIndex + 1} of ${progress.totalFiles}',
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