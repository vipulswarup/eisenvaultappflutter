import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/widgets/browse_item_tile.dart';
import 'package:flutter/material.dart';

/// Widget that displays a list of folder contents
class FolderContentList extends StatelessWidget {
  final List<BrowseItem> items;
  final Function(BrowseItem) onFolderTap;
  final Function(BrowseItem) onFileTap;
  final void Function(BrowseItem)? onDeleteTap;
  final bool showDeleteOption;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final bool isLoadingMore;
  final bool hasMoreItems;
  
  // Add these properties for selection mode
  final bool selectionMode;
  final Set<String> selectedItems;
  final Function(String, bool)? onItemSelected;

  const FolderContentList({
    Key? key,
    required this.items,
    required this.onFolderTap,
    required this.onFileTap,
    this.onDeleteTap,
    this.showDeleteOption = false,
    required this.onRefresh,
    required this.onLoadMore,
    required this.isLoadingMore,
    required this.hasMoreItems,
    this.selectionMode = false,
    this.selectedItems = const {},
    this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        itemCount: items.length + (hasMoreItems ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _buildLoadMoreIndicator();
          }
          
          final item = items[index];
          final isSelected = selectedItems.contains(item.id);
          
          return selectionMode
              ? _buildSelectableItem(context, item, isSelected)
              : BrowseItemTile(
                  item: item,
                  onTap: () {
                    if (item.type == 'folder' || item.isDepartment) {
                      onFolderTap(item);
                    } else {
                      onFileTap(item);
                    }
                  },
                  onDeleteTap: showDeleteOption ? () {
                    // Ignore the future
                    onDeleteTap?.call(item);
                  } : null,
                  showDeleteOption: showDeleteOption,
                );
        },
      ),
    );
  }
  
  Widget _buildSelectableItem(BuildContext context, BrowseItem item, bool isSelected) {
    return ListTile(
      leading: _buildItemIcon(item),
      title: Text(item.name),
      subtitle: Text(
        item.modifiedDate != null 
            ? 'Modified: ${_formatDate(item.modifiedDate!)}'
            : item.description ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) {
          onItemSelected?.call(item.id, value ?? false);
        },
      ),
      onTap: () {
        onItemSelected?.call(item.id, !isSelected);
      },
    );
  }
  
  Widget _buildLoadMoreIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  Widget _buildItemIcon(BrowseItem item) {
    // Implement your logic to build the item icon
    return const Icon(Icons.folder);
  }
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
