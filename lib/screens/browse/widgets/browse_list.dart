import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_list_item.dart';

class BrowseList extends StatefulWidget {
  final List<BrowseItem> items;
  final bool isLoading;
  final String? errorMessage;
  final Function(BrowseItem) onItemTap;
  final Function(BrowseItem) onItemLongPress;
  final bool isOffline;
  final bool isInSelectionMode;
  final Set<String> selectedItems;
  final Function(String, bool) onItemSelectionChanged;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final bool hasMoreItems;

  const BrowseList({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    required this.onItemTap,
    required this.onItemLongPress,
    required this.isOffline,
    this.isInSelectionMode = false,
    this.selectedItems = const {},
    required this.onItemSelectionChanged,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.hasMoreItems = false,
  });

  @override
  State<BrowseList> createState() => _BrowseListState();
}

class _BrowseListState extends State<BrowseList> {
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
      if (widget.hasMoreItems && !widget.isLoadingMore && !_isLoadingMore && widget.onLoadMore != null) {
        setState(() {
          _isLoadingMore = true;
        });
        widget.onLoadMore!();
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
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: EVColors.statusError, size: 48),
            const SizedBox(height: 16),
            Text(
              widget.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: EVColors.statusError),
            ),
          ],
        ),
      );
    }

    if (widget.items.isEmpty) {
      return const Center(
        child: Text(
          'No items found',
          style: TextStyle(color: EVColors.textFieldHint),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.items.length + (widget.isLoadingMore || _isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.items.length && (widget.isLoadingMore || _isLoadingMore)) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = widget.items[index];
        final isSelected = widget.selectedItems.contains(item.id);
        return BrowseListItem(
          item: item,
          onTap: () {
            if (widget.isInSelectionMode) {
              widget.onItemSelectionChanged(item.id, !isSelected);
            } else {
              widget.onItemTap(item);
            }
          },
          onLongPress: () {
            if (!widget.isInSelectionMode) {
              widget.onItemLongPress(item);
            }
          },
          isSelected: isSelected,
          showSelectionCheckbox: widget.isInSelectionMode,
          onSelectionChanged: (selected) => widget.onItemSelectionChanged(item.id, selected),
        );
      },
    );
  }
} 