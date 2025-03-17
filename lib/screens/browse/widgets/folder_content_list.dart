import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/widgets/browse_item_tile.dart';
import 'package:flutter/material.dart';

/// Widget that displays a list of folder contents
class FolderContentList extends StatefulWidget {
  final List<BrowseItem> items;
  final Function(BrowseItem) onFolderTap;
  final Function(BrowseItem) onFileTap;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool isLoadingMore;
  final bool hasMoreItems;

  const FolderContentList({
    Key? key,
    required this.items,
    required this.onFolderTap,
    required this.onFileTap,
    required this.onRefresh,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.hasMoreItems = false,
  }) : super(key: key);

  @override
  State<FolderContentList> createState() => _FolderContentListState();
}

class _FolderContentListState extends State<FolderContentList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (widget.onLoadMore == null || !widget.hasMoreItems || widget.isLoadingMore) {
      return;
    }

    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.items.length + (widget.hasMoreItems ? 1 : 0),
              cacheExtent: 500, // Increase cache to reduce rebuilds
              itemBuilder: (context, index) {
                // Show loading indicator at the end
                if (index == widget.items.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final item = widget.items[index];
                return BrowseItemTile(
                  item: item,
                  onTap: () {
                    // If the item is a folder or department, navigate to it
                    if (item.type == 'folder' || item.isDepartment) {
                      widget.onFolderTap(item);
                    } else {
                      widget.onFileTap(item);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
