import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';

class DownloadProgressIndicator extends StatelessWidget {
  final String fileName;
  final double progress;
  final int totalFiles;
  final int currentFileIndex;
  final VoidCallback? onMinimize;
  final bool isMinimized;

  const DownloadProgressIndicator({
    Key? key,
    required this.fileName,
    required this.progress,
    required this.totalFiles,
    required this.currentFileIndex,
    this.onMinimize,
    this.isMinimized = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isMinimized) {
      return _buildMinimizedIndicator(context);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EVColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: EVColors.cardShadow,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Downloading for offline use ($currentFileIndex of $totalFiles)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: EVColors.textDefault,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: EVColors.textLightGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onMinimize != null)
                  IconButton(
                    icon: const Icon(Icons.minimize, color: EVColors.iconGrey),
                    onPressed: onMinimize,
                    tooltip: 'Minimize',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: EVColors.iconGrey.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(EVColors.buttonBackground),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please keep the app open while files are being downloaded',
              style: TextStyle(
                fontSize: 12,
                color: EVColors.textLightGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimizedIndicator(BuildContext context) {
    return GestureDetector(
      onTap: onMinimize,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: EVColors.buttonBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.download_rounded,
              color: EVColors.buttonForeground,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Downloading ($currentFileIndex/$totalFiles)',
              style: const TextStyle(
                color: EVColors.buttonForeground,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}