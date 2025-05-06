import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';

class DownloadProgressIndicator extends StatelessWidget {
  const DownloadProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadManager>(
      builder: (context, downloadManager, child) {
        final progress = downloadManager.currentProgress;
        if (progress == null) {
          return const SizedBox.shrink();
        }

        // Modal overlay
        return Stack(
          children: [
            // Semi-transparent background
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
            // Centered card
            Center(
              child: Card(
                color: EVColors.cardBackground,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.download, color: EVColors.buttonBackground, size: 36),
                      const SizedBox(height: 16),
                      Text(
                        progress.totalFiles > 1
                          ? 'Downloading file ${progress.currentFileIndex} of ${progress.totalFiles}'
                          : 'Downloading file',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: EVColors.textDefault,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress.fileName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: EVColors.textGrey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 260,
                        child: LinearProgressIndicator(
                          value: progress.progress,
                          backgroundColor: EVColors.textFieldHint.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(EVColors.buttonBackground),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress.progress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: EVColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
} 