import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/folder_content_list.dart';
import '../state/browse_screen_state.dart';

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
    return Consumer<BrowseScreenState>(
      builder: (context, state, child) {
        if (state.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.controller.errorMessage != null) {
          return Center(
            child: Text(
              state.controller.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: state.refreshCurrentFolder,
          child: FolderContentList(
            items: state.controller.items,
            selectionMode: state.isInSelectionMode,
            selectedItems: state.selectedItems,
            onItemSelected: (itemId, selected) {
              state.toggleItemSelection(itemId);
            },
            onFolderTap: onFolderTap,
            onFileTap: onFileTap,
            onDeleteTap: !state.isOffline ? onDeleteTap : null,
            showDeleteOption: _shouldShowDeleteOption(state),
            onRefresh: state.refreshCurrentFolder,
            onLoadMore: state.controller.loadMoreItems,
            isLoadingMore: state.controller.isLoadingMore,
            hasMoreItems: state.controller.hasMoreItems,
            isItemAvailableOffline: state.controller.isItemAvailableOffline,
            onOfflineToggle: !state.isOffline ? state.controller.toggleOfflineAvailability : null,
          ),
        );
      },
    );
  }

  bool _shouldShowDeleteOption(BrowseScreenState state) {
    return state.controller.currentFolder != null && 
           state.controller.currentFolder!.id != 'root' && 
           state.controller.currentFolder!.canWrite && 
           !state.isOffline;
  }
} 