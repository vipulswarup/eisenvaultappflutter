import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/folder_content_list.dart';
import '../state/browse_screen_state.dart';
import '../browse_screen_controller.dart';

/// Displays the main content area for browsing folders and files.
/// This widget does NOT render a breadcrumb/navigation bar.
/// The parent screen (BrowseScreen) is responsible for rendering the breadcrumb.
class BrowseContent extends StatelessWidget {
  final Function(BrowseItem) onFolderTap;
  final Function(BrowseItem) onFileTap;
  final Function(BrowseItem)? onDeleteTap;
  final Function(BrowseItem)? onRenameTap;
  final bool selectionMode;
  final Set<String> selectedItems;
  final Function(String, bool)? onSelectionChanged;
  final Future<bool> Function(String)? isItemFavorite;
  final Function(BrowseItem)? onFavoriteToggle;

  const BrowseContent({
    super.key,
    required this.onFolderTap,
    required this.onFileTap,
    this.onDeleteTap,
    this.onRenameTap,
    this.selectionMode = false,
    this.selectedItems = const {},
    this.onSelectionChanged,
    this.isItemFavorite,
    this.onFavoriteToggle,
  });
  @override
  Widget build(BuildContext context) {
    return Consumer<BrowseScreenController>(
      builder: (context, controller, child) {
        final state = Provider.of<BrowseScreenState>(context);
        
        // Show loading indicator
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Show error message if any
        if (controller.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      controller.loadDepartments();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Show folder content list only (no breadcrumb here!)
        return FolderContentList(
          items: controller.items,
          onFolderTap: onFolderTap,
          onFileTap: onFileTap,
          onDeleteTap: onDeleteTap,
          onRenameTap: onRenameTap,
          showDeleteOption: _shouldShowDeleteOption(state, controller),
          showRenameOption: _shouldShowRenameOption(state, controller),
          onRefresh: () async {
            if (controller.currentFolder != null) {
              await controller.loadFolderContents(controller.currentFolder!);
            } else {
              await controller.loadDepartments();
            }
          },
          onLoadMore: controller.loadMoreItems,
          isLoadingMore: controller.isLoadingMore,
          hasMoreItems: controller.hasMoreItems,
          selectionMode: state.isInSelectionMode,
          selectedItems: state.selectedItems,
          onItemSelected: (itemId, selected) {
            state.toggleItemSelection(itemId);
          },
          isItemAvailableOffline: controller.isItemAvailableOffline,
          onOfflineToggle: controller.toggleOfflineAvailability,
          isItemFavorite: isItemFavorite,
          onFavoriteToggle: onFavoriteToggle,
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

  bool _shouldShowRenameOption(BrowseScreenState state, BrowseScreenController controller) {
    return controller.currentFolder != null && 
           controller.currentFolder?.id != 'root' && 
           controller.currentFolder?.canWrite == true && 
           !state.isOffline;
  }
}