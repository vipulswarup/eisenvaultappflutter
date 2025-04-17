import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import '../state/browse_screen_state.dart';

class BrowseActions extends StatelessWidget {
  final VoidCallback onUploadTap;
  final VoidCallback onBatchDeleteTap;

  const BrowseActions({
    Key? key,
    required this.onUploadTap,
    required this.onBatchDeleteTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<BrowseScreenState>(
      builder: (context, state, child) {
        // Don't show FAB in offline mode
        if (state.isOffline) {
          return const SizedBox.shrink();
        }

        // Show different FAB based on selection mode
        if (state.isInSelectionMode) {
          return _buildSelectionModeFAB(state);
        }

        // Show upload FAB only when in a folder that allows writing
        if (_canShowUploadFAB(state)) {
          return _buildUploadFAB();
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSelectionModeFAB(BrowseScreenState state) {
    if (state.selectedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: onBatchDeleteTap,
      backgroundColor: Colors.red,
      child: const Icon(Icons.delete),
    );
  }

  Widget _buildUploadFAB() {
    return FloatingActionButton(
      onPressed: onUploadTap,
      backgroundColor: EVColors.primaryBlue,
      child: const Icon(Icons.upload_file),
    );
  }

  bool _canShowUploadFAB(BrowseScreenState state) {
    final currentFolder = state.controller?.currentFolder;
    return currentFolder != null && 
           currentFolder.id != 'root' && 
           currentFolder.canWrite;
  }
} 