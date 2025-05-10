import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';

/// Widget that displays a banner when the device is offline
/// and monitors connectivity changes
class OfflineModeIndicator extends StatefulWidget {
  final Widget child;
  final Function(bool)? onConnectivityChanged;
  final SyncService syncService;
  final bool forceOfflineMode; // New parameter

  const OfflineModeIndicator({
    Key? key,
    required this.child,
    this.onConnectivityChanged,
    required this.syncService,
    this.forceOfflineMode = false, // Default to false
  }) : super(key: key);

  @override
  State<OfflineModeIndicator> createState() => _OfflineModeIndicatorState();
}

class _OfflineModeIndicatorState extends State<OfflineModeIndicator> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }
  
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print('Error checking connectivity: $e');
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (!mounted) return;
    
    final isNowOffline = results.contains(ConnectivityResult.none) || results.contains(ConnectivityResult.other);
    
    setState(() {
      _isOffline = isNowOffline;
    });
    
    if (_isOffline) {
      widget.syncService.stopPeriodicSync();
    } else {
      widget.syncService.startPeriodicSync();
    }
  }

  @override
  void didUpdateWidget(OfflineModeIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If forceOfflineMode changed, update the offline status
    if (widget.forceOfflineMode != oldWidget.forceOfflineMode) {
      _updateConnectionStatus([widget.forceOfflineMode ? ConnectivityResult.none : ConnectivityResult.mobile]);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Show offline banner if offline
        if (_isOffline)
          _buildOfflineBanner(),
        
        // Always show the child widget
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'You are offline. Some features may be limited.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _showOfflineInfoDialog(context);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'INFO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Mode'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are currently offline. In offline mode:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• You can view previously downloaded files'),
            Text('• You can navigate through downloaded folders'),
            Text('• You cannot upload new content'),
            Text('• You cannot modify or delete content'),
            Text('• Search functionality is limited to offline content'),
            SizedBox(height: 12),
            Text(
              'Your content will automatically sync when you reconnect to the internet.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

