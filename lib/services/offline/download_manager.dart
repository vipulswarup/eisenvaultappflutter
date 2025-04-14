import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:eisenvaultappflutter/services/offline/download_progress.dart';

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  
  DownloadManager._internal();

  bool _isDownloading = false;
  DownloadProgress? _currentProgress;
  bool _isMinimized = false;

  // Stream controller for progress updates
  final _progressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  bool get isDownloading => _isDownloading;
  DownloadProgress? get currentProgress => _currentProgress;
  bool get isMinimized => _isMinimized;

  void startDownload() {
    _isDownloading = true;
    _isMinimized = false;
    notifyListeners();
  }

  void updateProgress(DownloadProgress progress) {
    _currentProgress = progress;
    _progressController.add(progress);
    notifyListeners();
  }

  void completeDownload() {
    _isDownloading = false;
    _currentProgress = null;
    _isMinimized = false;
    notifyListeners();
  }

  void toggleMinimized() {
    _isMinimized = !_isMinimized;
    notifyListeners();
  }

  @override
  void dispose() {
    _progressController.close();
    super.dispose();
  }
} 