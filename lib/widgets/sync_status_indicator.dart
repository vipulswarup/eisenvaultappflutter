import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';

class SyncStatusIndicator extends StatefulWidget {
  final SyncService syncService;
  
  const SyncStatusIndicator({Key? key, required this.syncService}) : super(key: key);

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  bool _isSyncing = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    widget.syncService.onSyncStarted = () {
      setState(() {
        _isSyncing = true;
        _message = 'Syncing...';
      });
    };
    
    widget.syncService.onSyncCompleted = () {
      setState(() {
        _isSyncing = false;
        _message = 'Sync complete';
      });
    };
    
    widget.syncService.onSyncProgress = (msg) {
      setState(() {
        _message = msg;
      });
    };
    
    widget.syncService.onSyncError = (error) {
      setState(() {
        _isSyncing = false;
        _message = 'Sync error: $error';
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSyncing && _message.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: _isSyncing ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSyncing) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Text(_message, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
