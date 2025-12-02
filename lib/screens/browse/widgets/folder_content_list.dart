import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/widgets/browse_item_tile.dart';
import 'package:provider/provider.dart';
import '../state/browse_screen_state.dart';

/// Widget that displays a list of folder contents
class FolderContentList extends StatefulWidget {
  final List<BrowseItem> items;
  final Function(BrowseItem) onFolderTap;
  final Function(BrowseItem) onFileTap;
  final Function(BrowseItem)? onDeleteTap;
  final Function(BrowseItem)? onRenameTap;
  final bool showDeleteOption;
  final bool showRenameOption;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final bool isLoadingMore;
  final bool hasMoreItems;
  
  // Add these properties for selection mode
  final bool selectionMode;
  final Set<String> selectedItems;
  final Function(String, bool)? onItemSelected;
  final Future<bool> Function(String)? isItemAvailableOffline;
  final Function(BrowseItem)? onOfflineToggle;
  final Future<bool> Function(String)? isItemFavorite;
  final Function(BrowseItem)? onFavoriteToggle;

  const FolderContentList({
    super.key,
    required this.items,
    required this.onFolderTap,
    required this.onFileTap,
    this.onDeleteTap,
    this.onRenameTap,
    this.showDeleteOption = false,
    this.showRenameOption = false,
    required this.onRefresh,
    required this.onLoadMore,
    required this.isLoadingMore,
    required this.hasMoreItems,
    this.selectionMode = false,
    this.selectedItems = const {},
    this.onItemSelected,
    this.isItemAvailableOffline,
    this.onOfflineToggle,
    this.isItemFavorite,
    this.onFavoriteToggle,
  });

  @override
  State<FolderContentList> createState() => _FolderContentListState();
}

class _FolderContentListState extends State<FolderContentList> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (widget.hasMoreItems && !widget.isLoadingMore && !_isLoadingMore) {
        setState(() {
          _isLoadingMore = true;
        });
        widget.onLoadMore();
        // Reset loading state after a short delay to allow the controller to update
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<BrowseScreenState>(context, listen: false);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.items.length + (widget.hasMoreItems ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.items.length) {
            return _buildLoadMoreIndicator();
          }
          final item = widget.items[index];
          final isSelected = widget.selectedItems.contains(item.id);

          // Always pass onSelectionChanged to BrowseItemTile
          return widget.selectionMode
              ? _buildSelectableItem(context, item, isSelected)
              : FutureBuilder<Map<String, bool>>(
                  future: Future.wait([
                    widget.isItemAvailableOffline?.call(item.id) ?? Future.value(false),
                    widget.isItemFavorite?.call(item.id) ?? Future.value(false),
                  ]).then((results) => {
                    'offline': results[0],
                    'favorite': results[1],
                  }),
                  builder: (context, snapshot) {
                    final isAvailableOffline = snapshot.data?['offline'] ?? false;
                    final isFavorite = snapshot.data?['favorite'] ?? false;
                    return BrowseItemTile(
                      item: item,
                      onTap: () {
                        if (item.type == 'folder' || item.isDepartment) {
                          widget.onFolderTap(item);
                        } else {
                          widget.onFileTap(item);
                        }
                      },
                      onDeleteTap: widget.showDeleteOption ? widget.onDeleteTap : null,
                      onRenameTap: widget.showRenameOption ? widget.onRenameTap : null,
                      showDeleteOption: widget.showDeleteOption,
                      showRenameOption: widget.showRenameOption,
                      isAvailableOffline: isAvailableOffline,
                      onOfflineToggle: widget.onOfflineToggle,
                      isFavorite: isFavorite,
                      onFavoriteToggle: widget.onFavoriteToggle,
                      selectionMode: false,
                      isSelected: isSelected,
                      onSelectionChanged: (selected) {
                        // If not in selection mode, enter it and select the item
                        if (!state.isInSelectionMode) {
                          state.toggleSelectionMode();
                        }
                        state.toggleItemSelection(item.id);
                      },
                    );
                  },
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
          widget.onItemSelected?.call(item.id, value ?? false);
        },
      ),
      onTap: () {
        widget.onItemSelected?.call(item.id, !isSelected);
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
    
    if (item.isDepartment) {
      // Department/Site icon
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: EVColors.paletteAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.business,
          color: EVColors.paletteAccent,
          size: 24,
        ),
      );
    } else if (item.type == 'folder') {
      // Folder icon
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.folder,
          color: Colors.amber,
          size: 24,
        ),
      );
    } else {
      // Document icon - determine icon based on file extension
      IconData iconData = _getDocumentIcon(item.name);
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          iconData,
          color: Colors.teal,
          size: 24,
        ),
      );
    }
  }

  IconData _getDocumentIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
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
