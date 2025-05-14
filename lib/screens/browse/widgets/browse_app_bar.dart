import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';

class BrowseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onDrawerOpen;
  final VoidCallback? onSearchTap;
  final VoidCallback? onLogoutTap;
  final bool showBackButton;
  final bool? Function()? onBackPressed;
  final bool isOfflineMode;
  final bool isInSelectionMode;
  final VoidCallback? onSelectionModeToggle;

  const BrowseAppBar({
    super.key,
    this.onDrawerOpen,
    this.onSearchTap,
    this.onLogoutTap,
    this.showBackButton = false,
    this.onBackPressed,
    this.isOfflineMode = false,
    this.isInSelectionMode = false,
    this.onSelectionModeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: EVColors.appBarBackground,
      foregroundColor: EVColors.appBarForeground,
      iconTheme: const IconThemeData(color: EVColors.appBarForeground),
      titleTextStyle: const TextStyle(
        color: EVColors.appBarForeground,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      actionsIconTheme: const IconThemeData(color: EVColors.appBarForeground),
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (onBackPressed?.call() ?? false) {
                  // Navigation handled by controller
                } else {
                  Navigator.of(context).pop();
                }
              },
            )
          : IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onDrawerOpen,
            ),
      title: Row(
        children: [
          const Text('Browse'),
          if (isOfflineMode)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: EVColors.statusWarning,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Offline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      actions: [
        if (!isOfflineMode) ...[
          IconButton(
            icon: Icon(isInSelectionMode ? Icons.close : Icons.select_all),
            onPressed: onSelectionModeToggle,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onSearchTap,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: onLogoutTap,
          ),
        ],
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
