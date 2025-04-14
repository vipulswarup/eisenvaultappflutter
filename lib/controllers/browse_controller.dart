// ... existing code ...
  // Remove test offline mode
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  // Remove test offline mode
  void _checkConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      _isOfflineMode = result == ConnectivityResult.none || result == ConnectivityResult.other;
      notifyListeners();
    });
  }
// ... existing code ... 