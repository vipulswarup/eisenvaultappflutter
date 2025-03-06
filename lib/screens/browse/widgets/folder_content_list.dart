import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/widgets/browse_item_tile.dart';
import 'package:flutter/material.dart';

/// Widget that displays a list of folder contents
class FolderContentList extends StatelessWidget {
  final List<BrowseItem> items;
  final Function(BrowseItem) onFolderTap;
  final Function(BrowseItem) onFileTap;
  final Future<void> Function() onRefresh;

  const FolderContentList({
    Key? key,
    required this.items,
    required this.onFolderTap,
    required this.onFileTap,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        itemCount: items.length,
        cacheExtent: 500, // Increase cache to reduce rebuilds
        itemBuilder: (context, index) {
          final item = items[index];
          return BrowseItemTile(
            item: item,
            onTap: () {
              // If the item is a folder or department, navigate to it
              if (item.type == 'folder' || item.isDepartment) {
                onFolderTap(item);
              } else {
                onFileTap(item);
              }
            },
          );
        },
      ),
    );
  }
}
