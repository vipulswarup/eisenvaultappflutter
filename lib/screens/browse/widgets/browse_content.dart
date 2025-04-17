import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/folder_content_list.dart';
import '../state/browse_screen_state.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

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
    return Consumer<BrowseScreenState>(
      builder: (context, state, child) {
        EVLogger.debug('BrowseContent Consumer builder called', {
          'isLoading': state.controller?.isLoading ?? false,
          'hasError': state.controller?.errorMessage != null,
          'itemCount': state.controller?.items.length ?? 0,
          'isControllerInitialized': state.isControllerInitialized,
        });
        
        if (state.isControllerInitialized && state.controller?.isLoading == true) {
          EVLogger.debug('BrowseContent showing loading indicator');
          return const Center(child: CircularProgressIndicator());
        }

        if (state.controller?.errorMessage != null) {
          EVLogger.debug('BrowseContent showing error message', {
            'error': state.controller?.errorMessage
          });
          return Center(
            child: Text(
              state.controller?.errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        EVLogger.debug('BrowseContent building FolderContentList', {
          'itemCount': state.controller?.items.length ?? 0
        });
        return RefreshIndicator(
          onRefresh: () => state.refreshCurrentView(),
          child: FolderContentList(
            items: state.controller?.items ?? [],
            selectionMode: state.isInSelectionMode,
            selectedItems: state.selectedItems,
            onItemSelected: (itemId, selected) {
              state.toggleItemSelection(itemId);
            },
            onFolderTap: onFolderTap,
            onFileTap: onFileTap,
            onDeleteTap: !state.isOffline ? onDeleteTap : null,
            showDeleteOption: _shouldShowDeleteOption(state),
            onRefresh: () => state.refreshCurrentView(),
            onLoadMore: state.controller?.loadMoreItems ?? (() {}),
            isLoadingMore: state.controller?.isLoadingMore ?? false,
            hasMoreItems: state.controller?.hasMoreItems ?? false,
            isItemAvailableOffline: state.controller?.isItemAvailableOffline,
            onOfflineToggle: state.controller?.toggleOfflineAvailability,
          ),
        );
      },
    );
  }

  bool _shouldShowDeleteOption(BrowseScreenState state) {
    return state.controller?.currentFolder != null && 
           state.controller?.currentFolder?.id != 'root' && 
           state.controller?.currentFolder?.canWrite == true && 
           !state.isOffline;
  }
} 