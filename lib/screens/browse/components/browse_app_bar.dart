import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../models/browse_item.dart';

class BrowseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isAtDepartmentsList;
  final bool hasItems;
  final bool isInSelectionMode;
  final VoidCallback onBackPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onSelectionModeToggle;
  final VoidCallback onLogoutPressed;

  const BrowseAppBar({
    Key? key,
    required this.title,
    required this.isAtDepartmentsList,
    required this.hasItems,
    required this.isInSelectionMode,
    required this.onBackPressed,
    required this.onSearchPressed,
    required this.onSelectionModeToggle,
    required this.onLogoutPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: isAtDepartmentsList
          ? null  // Use default drawer hamburger icon
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed,
            ),
      title: Text(title),
      backgroundColor: EVColors.appBarBackground,
      foregroundColor: EVColors.appBarForeground,
      actions: [
        // Add search button
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: onSearchPressed,
        ),
        // Only show selection mode toggle if there are items
        if (hasItems)
          IconButton(
            icon: Icon(isInSelectionMode ? Icons.cancel : Icons.select_all),
            tooltip: isInSelectionMode ? 'Cancel selection' : 'Select items',
            onPressed: onSelectionModeToggle,
          ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: onLogoutPressed,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
