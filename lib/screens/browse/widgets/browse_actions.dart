import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import '../state/browse_screen_state.dart';
import '../browse_screen_controller.dart';

class BrowseActions extends StatelessWidget {
  final VoidCallback onUploadTap;
  final VoidCallback onBatchDeleteTap;
  final VoidCallback onBatchOfflineTap;

  const BrowseActions({
    Key? key,
    required this.onUploadTap,
    required this.onBatchDeleteTap,
    required this.onBatchOfflineTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<BrowseScreenState, BrowseScreenController>(
      builder: (context, state, controller, child) {
        // Don't show FAB in offline mode
        if (state.isOffline) {
          return const SizedBox.shrink();
        }

        // Show different FAB based on selection mode
        if (state.isInSelectionMode) {
          return _buildSelectionModeFAB(state, controller);
        }

        // Show upload FAB only when in a folder that allows writing
        if (_canShowUploadFAB(controller)) {
          return _buildUploadFAB();
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSelectionModeFAB(BrowseScreenState state, BrowseScreenController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (state.selectedItems.isNotEmpty) ...[
          FloatingActionButton(
            heroTag: 'offline',
            onPressed: () {
              onBatchOfflineTap();
            },
            child: const Icon(Icons.download),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'delete',
            onPressed: onBatchDeleteTap,
            backgroundColor: Colors.red,
            child: const Icon(Icons.delete),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadFAB() {
    return FloatingActionButton(
      heroTag: 'upload',
      onPressed: onUploadTap,
      child: const Icon(Icons.upload),
    );
  }

  bool _canShowUploadFAB(BrowseScreenController controller) {
    return controller.currentFolder != null && 
           controller.currentFolder?.id != 'root' && 
           controller.currentFolder?.canWrite == true;
  }
}