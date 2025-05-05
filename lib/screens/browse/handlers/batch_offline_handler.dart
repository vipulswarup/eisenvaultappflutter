import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';

class BatchOfflineHandler {
  final BuildContext context;
  final String instanceType;
  final String baseUrl;
  final String authToken;
  final OfflineManager offlineManager;
  final List<BrowseItem> Function() getSelectedItems;
  final VoidCallback onOfflineSuccess;

  BatchOfflineHandler({
    required this.context,
    required this.instanceType,
    required this.baseUrl,
    required this.authToken,
    required this.offlineManager,
    required this.getSelectedItems,
    required this.onOfflineSuccess,
  });

  Future<void> handleBatchOffline() async {
    final selectedItems = getSelectedItems();
    
    if (selectedItems.isEmpty) {
      
      return;
    }

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Make Selected Items Available Offline'),
          content: Text(
            'Are you sure you want to make ${selectedItems.length} item(s) available offline?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        
        return;
      }

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Process each item
      for (final item in selectedItems) {
        if (item.type != 'folder') { // Only files can be made available offline
          
          await offlineManager.keepOffline(item);
        } else {
          
        }
      }

      // Close progress dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedItems.length} item(s) made available offline'),
          backgroundColor: Colors.green,
        ),
      );

      
      onOfflineSuccess();
    } catch (e) {
      EVLogger.error('Error making items available offline', e);
      // Close progress dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 