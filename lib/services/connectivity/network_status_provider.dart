import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkStatusProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  NetworkStatusProvider() {
    _init();
  }

  bool get isConnected => _isConnected;

  void _init() async {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results.first);
    });
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results.first);
  }

  void _updateStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    if (wasConnected != _isConnected) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
