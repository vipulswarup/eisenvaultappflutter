import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Widget that displays a banner when the device is offline
/// and monitors connectivity changes
class OfflineModeIndicator extends StatefulWidget {
  final Widget child;
  final Function(bool)? onConnectivityChanged;

  const OfflineModeIndicator({
    Key? key,
    required this.child,
    this.onConnectivityChanged,
  }) : super(key: key);

  @override
  State<OfflineModeIndicator> createState() => _OfflineModeIndicatorState();
}

class _OfflineModeIndicatorState extends State<OfflineModeIndicator> {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    // Check initial connectivity state
    _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      EVLogger.error('Error checking connectivity', e);
      // Assume online if we can't check
      _updateConnectionStatus(ConnectivityResult.mobile);
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final bool wasOffline = _isOffline;
    final bool isNowOffline = result == ConnectivityResult.none;
    
    // Only update state if there's a change
    if (wasOffline != isNowOffline) {
      setState(() {
        _isOffline = isNowOffline;
      });
      
      // Notify parent widget about connectivity change
      if (widget.onConnectivityChanged != null) {
        widget.onConnectivityChanged!(_isOffline);
      }
      
      // Log the connectivity change
      EVLogger.info('Connection status changed', {
        'isOffline': _isOffline,
        'connectivityResult': result.name,
      });
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
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
