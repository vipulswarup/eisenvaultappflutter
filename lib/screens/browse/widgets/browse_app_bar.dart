import 'package:flutter/material.dart';

class BrowseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onDrawerOpen;
  final VoidCallback? onSearchTap;
  final VoidCallback? onLogoutTap;
  final bool showBackButton;
  final bool showMenuButton;
  final bool? Function()? onBackPressed;
  final bool isOfflineMode;
  final bool isInSelectionMode;
  final VoidCallback? onSelectionModeToggle;
  final VoidCallback? onFilterSortTap;
  final bool hasActiveFilters;

  const BrowseAppBar({
    super.key,
    this.onDrawerOpen,
    this.onSearchTap,
    this.onLogoutTap,
    this.showBackButton = false,
    this.showMenuButton = true,
    this.onBackPressed,
    this.isOfflineMode = false,
    this.isInSelectionMode = false,
    this.onSelectionModeToggle,
    this.onFilterSortTap,
    this.hasActiveFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return AppBar(
      automaticallyImplyLeading: false,
      leading:
          showBackButton
              ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (!(onBackPressed?.call() ?? false))
                    Navigator.of(context).maybePop();
                },
              )
              : showMenuButton
              ? IconButton(
                tooltip: 'Open navigation',
                icon: const Icon(Icons.menu),
                onPressed: onDrawerOpen,
              )
              : null,
      title: Text(
        isOfflineMode ? 'Offline files' : 'Documents',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (!isOfflineMode) ...[
          IconButton(
            tooltip: 'Search documents',
            icon: const Icon(Icons.search),
            onPressed: onSearchTap,
          ),
          if (!compact) ...[
            IconButton(
              tooltip: isInSelectionMode ? 'Cancel selection' : 'Select items',
              icon: Icon(isInSelectionMode ? Icons.close : Icons.checklist),
              onPressed: onSelectionModeToggle,
            ),
            IconButton(
              tooltip: hasActiveFilters ? 'Filters active' : 'Filter and sort',
              icon: Badge(
                isLabelVisible: hasActiveFilters,
                child: const Icon(Icons.tune),
              ),
              onPressed: onFilterSortTap,
            ),
          ],
          PopupMenuButton<String>(
            tooltip: 'More actions',
            icon: Badge(
              isLabelVisible: compact && hasActiveFilters,
              child: const Icon(Icons.more_horiz),
            ),
            onSelected: (action) {
              switch (action) {
                case 'select':
                  onSelectionModeToggle?.call();
                case 'filter':
                  onFilterSortTap?.call();
                case 'logout':
                  onLogoutTap?.call();
                case 'navigation':
                  onDrawerOpen?.call();
              }
            },
            itemBuilder:
                (_) => [
                  if (showMenuButton && showBackButton)
                    const PopupMenuItem(
                      value: 'navigation',
                      child: Text('Open navigation'),
                    ),
                  if (compact) ...[
                    PopupMenuItem(
                      value: 'select',
                      child: Text(
                        isInSelectionMode ? 'Cancel selection' : 'Select items',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'filter',
                      child: Text('Filter and sort'),
                    ),
                  ],
                  const PopupMenuItem(value: 'logout', child: Text('Sign out')),
                ],
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
