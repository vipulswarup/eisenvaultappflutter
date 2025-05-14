import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';

/// A widget that shows the current sync status and progress
class SyncStatusIndicator extends StatefulWidget {
  final SyncService syncService;

  const SyncStatusIndicator({
    super.key,
    required this.syncService,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  bool _isSyncing = false;
  String _syncStatus = '';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _setupSyncCallbacks();
  }

  void _setupSyncCallbacks() {
    widget.syncService.onSyncStarted = () {
      if (mounted) {
        setState(() {
          _isSyncing = true;
          _hasError = false;
          _syncStatus = 'Starting sync...';
        });
      }
    };

    widget.syncService.onSyncCompleted = () {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hasError = false;
          _syncStatus = 'Sync completed';
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _syncStatus = '';
              });
            }
          });
        });
      }
    };

    widget.syncService.onSyncProgress = (message) {
      if (mounted) {
        setState(() {
          _syncStatus = message;
        });
      }
    };

    widget.syncService.onSyncError = (error) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hasError = true;
          _syncStatus = 'Sync error: $error';
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_syncStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _hasError
            ? EVColors.errorRed.withOpacity(0.1)
            : EVColors.buttonBackground.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSyncing) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(EVColors.buttonBackground),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            _hasError ? Icons.error : Icons.sync,
            size: 16,
            color: _hasError ? EVColors.errorRed : EVColors.buttonBackground,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _syncStatus,
              style: TextStyle(
                color: _hasError ? EVColors.errorRed : EVColors.buttonBackground,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.syncService.onSyncStarted = null;
    widget.syncService.onSyncCompleted = null;
    widget.syncService.onSyncProgress = null;
    widget.syncService.onSyncError = null;
    super.dispose();
  }
}