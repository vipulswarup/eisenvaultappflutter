import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/folder_content_list.dart';
import '../state/browse_screen_state.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import '../browse_screen_controller.dart';

class BrowseContent extends StatelessWidget {
  final Function(BrowseItem) onFolderTap;
  final Function(BrowseItem) onFileTap;
  final Function(BrowseItem)? onDeleteTap;

  const BrowseContent({
    Key? key,
    required this.onFolderTap,
    required this.onFileTap,
    this.onDeleteTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    EVLogger.debug('BrowseContent.build called');
    
    // Add direct consumer for the controller to get real-time loading state
    return Consumer2<BrowseScreenState, BrowseScreenController>(
      builder: (context, state, controller, child) {
        EVLogger.debug('BrowseContent Consumer builder called', {
          'isLoading': controller.isLoading, // Direct reference to controller
          'hasError': controller.errorMessage != null,
          'itemCount': controller.items.length,
          'isControllerInitialized': state.isControllerInitialized,
        });
        
        if (state.isControllerInitialized && controller.isLoading) { // Direct reference
          EVLogger.debug('BrowseContent showing loading indicator');
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage != null) { // Direct reference
          EVLogger.debug('BrowseContent showing error message', {
            'error': controller.errorMessage
          });
          return Center(
            child: Text(
              controller.errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        // Add this block to handle empty departments list
        if (controller.items.isEmpty && controller.currentFolder == null) {
          EVLogger.debug('BrowseContent showing empty departments message');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No Departments Found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You don\'t have access to any departments in this repository.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => state.refreshCurrentView(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        // Add this block to handle empty folder
        if (controller.items.isEmpty && controller.currentFolder != null) {
          EVLogger.debug('BrowseContent showing empty folder message');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Empty Folder',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This folder is empty.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => state.refreshCurrentView(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        EVLogger.debug('BrowseContent building FolderContentList', {
          'itemCount': controller.items.length
        });
        return RefreshIndicator(
          onRefresh: () => state.refreshCurrentView(),
          child: FolderContentList(
            items: controller.items,
            selectionMode: state.isInSelectionMode,
            selectedItems: state.selectedItems,
            onItemSelected: (itemId, selected) {
              state.toggleItemSelection(itemId);
            },
            onFolderTap: onFolderTap,
            onFileTap: onFileTap,
            onDeleteTap: !state.isOffline ? onDeleteTap : null,
            showDeleteOption: _shouldShowDeleteOption(state, controller),
            onRefresh: () => state.refreshCurrentView(),
            onLoadMore: controller.loadMoreItems,
            isLoadingMore: controller.isLoadingMore,
            hasMoreItems: controller.hasMoreItems,
            isItemAvailableOffline: controller.isItemAvailableOffline,
            onOfflineToggle: controller.toggleOfflineAvailability,
          ),
        );
      },
    );
  }

  bool _shouldShowDeleteOption(BrowseScreenState state, BrowseScreenController controller) {
    return controller.currentFolder != null && 
           controller.currentFolder?.id != 'root' && 
           controller.currentFolder?.canWrite == true && 
           !state.isOffline;
  }
}
