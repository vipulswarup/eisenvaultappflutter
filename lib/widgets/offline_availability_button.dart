import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';

/// A button widget that allows users to mark/unmark items for offline availability
class OfflineAvailabilityButton extends StatefulWidget {
  final BrowseItem item;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final bool isAvailableOffline;
  final Function(bool) onAvailabilityChanged;
  final String? parentId;

  const OfflineAvailabilityButton({
    Key? key,
    required this.item,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.isAvailableOffline,
    required this.onAvailabilityChanged,
    this.parentId,
  }) : super(key: key);

  @override
  State<OfflineAvailabilityButton> createState() => _OfflineAvailabilityButtonState();
}

class _OfflineAvailabilityButtonState extends State<OfflineAvailabilityButton> {
  late OfflineManager _offlineManager;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initOfflineManager();
  }

  Future<void> _initOfflineManager() async {
    _offlineManager = await OfflineManager.createDefault();
  }

  @override
  Widget build(BuildContext context) {
    EVLogger.debug('OfflineAvailabilityButton: build called');
    return IconButton(
      icon: _buildIcon(),
      tooltip: widget.isAvailableOffline 
          ? 'Remove from offline storage' 
          : 'Make available offline',
      onPressed: _isProcessing ? null : _toggleOfflineAvailability,
    );
  }

  Widget _buildIcon() {
    if (_isProcessing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(EVColors.buttonBackground),
        ),
      );
    }

    return Icon(
      widget.isAvailableOffline
          ? Icons.offline_pin
          : Icons.offline_pin_outlined,
      color: widget.isAvailableOffline
          ? EVColors.buttonBackground
          : EVColors.iconGrey,
    );
  }

  Future<void> _toggleOfflineAvailability() async {
    EVLogger.debug('OfflineAvailabilityButton: _toggleOfflineAvailability called');
    setState(() {
      _isProcessing = true;
    });

    try {
      if (widget.isAvailableOffline) {
        // Remove from offline storage
        final result = await _offlineManager.removeOffline(widget.item.id);

        if (result) {
          _showMessage('Removed from offline storage');
          widget.onAvailabilityChanged(false);
        } else {
          _showMessage('Failed to remove from offline storage', isError: true);
        }
      } else {
        // Add to offline storage
        final bool isFolder = widget.item.type == 'folder' || widget.item.isDepartment;
        
        // Show confirmation dialog if it's a folder
        if (isFolder) {
          final bool? confirm = await _showFolderConfirmationDialog();
          if (confirm != true) {
            setState(() {
              _isProcessing = false;
            });
            return;
          }
        }

        // Make available offline
        final downloadManager = Provider.of<DownloadManager>(context, listen: false);
        EVLogger.debug('Button: DownloadManager instance', {'hash': downloadManager.hashCode});
        await _offlineManager.keepOffline(
          widget.item,
          downloadManager: downloadManager,
          onError: (message) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: EVColors.errorRed,
                ),
              );
            }
          },
        );
        _showMessage('Added to offline storage');
        widget.onAvailabilityChanged(true);
      }
    } catch (e) {
      EVLogger.error('Error toggling offline availability', {
        'itemId': widget.item.id,
        'error': e.toString(),
      });
      _showMessage('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool?> _showFolderConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make folder available offline?'),
        content: Text(
          'This will download all files inside "${widget.item.name}" for offline access. '
          'This may use significant storage space depending on the folder contents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('MAKE AVAILABLE OFFLINE'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? EVColors.errorRed : EVColors.successGreen,
      ),
    );
  }
}