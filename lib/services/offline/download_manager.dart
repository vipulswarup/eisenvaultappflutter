import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:eisenvaultappflutter/services/offline/download_progress.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class DownloadManager extends ChangeNotifier {
  DownloadManager() {
    _progressController = StreamController<DownloadProgress>.broadcast();
  }

  bool _isDownloading = false;
  DownloadProgress? _currentProgress;
  bool _isMinimized = false;
  bool _isDisposed = false;
  bool _isCancelled = false;
  late StreamController<DownloadProgress> _progressController;

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  bool get isDownloading => _isDownloading;
  DownloadProgress? get currentProgress => _currentProgress;
  bool get isMinimized => _isMinimized;
  bool get isCancelled => _isCancelled;

  void startDownload() {
    if (_isDisposed) return;
    _isDownloading = true;
    _isMinimized = false;
    _isCancelled = false;
    // Initialize progress immediately
    _currentProgress = DownloadProgress(
      fileName: 'Preparing download...',
      progress: 0,
      totalFiles: 1,
      currentFileIndex: 0,
    );
    notifyListeners();
  }

  void updateProgress(DownloadProgress progress) {
    if (_isDisposed || _isCancelled) return;
    _currentProgress = progress;
    _isDownloading = true;
    
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
    notifyListeners();
  }

  void cancelDownload() {
    if (_isDisposed) return;
    _isCancelled = true;
    _isDownloading = false;
    _currentProgress = null;
    _isMinimized = false;
    notifyListeners();
  }

  void completeDownload() {
    if (_isDisposed || _isCancelled) return;
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
    _isDisposed = true;
    if (!_progressController.isClosed) {
      _progressController.close();
    }
    super.dispose();
  }
} 