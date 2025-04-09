import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// A button widget that allows users to mark/unmark items for offline availability
class OfflineAvailabilityButton extends StatefulWidget {
  final BrowseItem item;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final bool isAvailableOffline;
  final Function(bool) onAvailabilityChanged;
  final String? parentId; // Add parent ID parameter

  const OfflineAvailabilityButton({
    Key? key,
    required this.item,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.isAvailableOffline,
    required this.onAvailabilityChanged,
    this.parentId, // Add this parameter
  }) : super(key: key);

  @override
  State<OfflineAvailabilityButton> createState() => _OfflineAvailabilityButtonState();
}

class _OfflineAvailabilityButtonState extends State<OfflineAvailabilityButton> {
  final OfflineManager _offlineManager = OfflineManager.createDefault();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
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
          valueColor: AlwaysStoppedAnimation<Color>(EVColors.primaryBlue),
        ),
      );
    }

    return Icon(
      widget.isAvailableOffline
          ? Icons.offline_pin
          : Icons.offline_pin_outlined,
      color: widget.isAvailableOffline
          ? EVColors.primaryBlue
          : Colors.grey,
    );
  }

  Future<void> _toggleOfflineAvailability() async {
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

        // Create browse service for recursive folder download
        final browseService = isFolder 
            ? BrowseServiceFactory.getService(  // Use the correct method name
                widget.instanceType,
                widget.baseUrl,
                widget.authToken,
              )
            : null;

        // Make available offline with parent ID
        final result = await _offlineManager.keepOffline(
          widget.item,
          parentId: widget.parentId, // Pass parent ID
          recursiveForFolders: isFolder,
          browseService: browseService,
        );

        if (result) {
          _showMessage('Added to offline storage');
          widget.onAvailabilityChanged(true);
        } else {
          _showMessage('Failed to add to offline storage', isError: true);
        }
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
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
