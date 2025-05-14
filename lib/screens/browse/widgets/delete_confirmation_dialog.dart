import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';

/// A dialog that confirms deletion of items
class DeleteConfirmationDialog extends StatelessWidget {
  final List<BrowseItem> items;
  final Function() onConfirm;
  final bool isBatchDelete;

  const DeleteConfirmationDialog({
    super.key,
    required this.items,
    required this.onConfirm,
    this.isBatchDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: EVColors.screenBackground,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          minWidth: 300,
          maxHeight: 400,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isBatchDelete ? 'Delete Selected Items?' : 'Delete Item?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _buildConfirmationMessage(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (items.length > 1) ...[
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          item.type == 'folder' ? Icons.folder : Icons.insert_drive_file,
                          color: item.type == 'folder' ? Colors.amber : Colors.teal,
                        ),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      onConfirm();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('DELETE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildConfirmationMessage() {
    if (items.isEmpty) return '';
    
    if (items.length == 1) {
      final item = items.first;
      return 'Are you sure you want to delete "${item.name}"? This action cannot be undone.';
    }

    return 'Are you sure you want to delete ${items.length} items? This action cannot be undone.';
  }
} 