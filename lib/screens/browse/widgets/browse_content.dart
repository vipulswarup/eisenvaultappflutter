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
    return Consumer<BrowseScreenController>(
      builder: (context, controller, child) {
        final state = Provider.of<BrowseScreenState>(context);
        
        EVLogger.debug('FOLDER NAVIGATION: BrowseContent rebuild', {
          'isLoading': controller.isLoading,
          'hasError': controller.errorMessage != null,
          'itemCount': controller.items.length,
          'currentFolder': controller.currentFolder?.name,
        });
        
        // Show loading indicator
        if (controller.isLoading) {
          EVLogger.debug('FOLDER NAVIGATION: Showing loading indicator');
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
        
        // Show empty departments message
        if (controller.items.isEmpty && controller.currentFolder == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No Departments Found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You don\'t have access to any departments in this repository.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      controller.loadDepartments();
                    },
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Show empty folder message
        if (controller.items.isEmpty && controller.currentFolder != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_open, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Empty Folder',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This folder is empty.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.currentFolder != null) {
                        controller.loadFolderContents(controller.currentFolder!);
                      }
                    },
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Show folder content list
        return RefreshIndicator(
          onRefresh: () async {
            if (controller.currentFolder != null) {
              await controller.loadFolderContents(controller.currentFolder!);
            } else {
              await controller.loadDepartments();
            }
          },
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
