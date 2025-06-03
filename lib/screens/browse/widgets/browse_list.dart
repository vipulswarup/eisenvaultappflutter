import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_list_item.dart';

class BrowseList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: EVColors.statusError, size: 48),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: EVColors.statusError),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items found',
          style: TextStyle(color: EVColors.textFieldHint),
        ),
      );
    }

    final ScrollController _scrollController = ScrollController();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (hasMoreItems && !isLoadingMore && onLoadMore != null) {
          onLoadMore!();
        }
      }
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification) {
          if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
            if (hasMoreItems && !isLoadingMore && onLoadMore != null) {
              onLoadMore!();
            }
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: items.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length && isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = items[index];
          final isSelected = selectedItems.contains(item.id);
          return BrowseListItem(
            item: item,
            onTap: () {
              if (isInSelectionMode) {
                onItemSelectionChanged(item.id, !isSelected);
              } else {
                onItemTap(item);
              }
            },
            onLongPress: () {
              if (!isInSelectionMode) {
                onItemLongPress(item);
              }
            },
            isSelected: isSelected,
            showSelectionCheckbox: isInSelectionMode,
            onSelectionChanged: (selected) => onItemSelectionChanged(item.id, selected),
          );
        },
      ),
    );
  }
} 