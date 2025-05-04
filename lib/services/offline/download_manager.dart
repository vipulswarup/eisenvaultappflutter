import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:eisenvaultappflutter/services/offline/download_progress.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class DownloadManager extends ChangeNotifier {
  DownloadManager() {
    EVLogger.info('DownloadManager created', {'hashCode': hashCode});
  }

  bool _isDownloading = false;
  DownloadProgress? _currentProgress;
  bool _isMinimized = false;
  bool _isDisposed = false;

  // Stream controller for progress updates
  final _progressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  bool get isDownloading => _isDownloading;
  DownloadProgress? get currentProgress => _currentProgress;
  bool get isMinimized => _isMinimized;

  void startDownload() {
    EVLogger.info('DownloadManager.startDownload', {'hashCode': hashCode});
    if (_isDisposed) return;
    _isDownloading = true;
    _isMinimized = false;
    notifyListeners();
  }

  void updateProgress(DownloadProgress progress) {
    EVLogger.info('DownloadManager.updateProgress', {'hashCode': hashCode, 'progress': progress.progress});
    if (_isDisposed) return;
    _currentProgress = progress;
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
    notifyListeners();
  }

  void completeDownload() {
    EVLogger.info('DownloadManager.completeDownload', {'hashCode': hashCode});
    if (_isDisposed) return;
    _isDownloading = false;
    _currentProgress = null;
    _isMinimized = false;
    notifyListeners();
  }

  void toggleMinimized() {
    if (_isDisposed) return;
    _isMinimized = !_isMinimized;
    notifyListeners();
  }

  @override
  void dispose() {
    EVLogger.info('DownloadManager disposed', {'hashCode': hashCode});
    _isDisposed = true;
    if (!_progressController.isClosed) {
      _progressController.close();
    }
    super.dispose();
  }
} 