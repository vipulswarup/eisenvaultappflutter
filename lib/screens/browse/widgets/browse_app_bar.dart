import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:provider/provider.dart';
import '../state/browse_screen_state.dart';

class BrowseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onDrawerOpen;
  final VoidCallback onSearchTap;
  final VoidCallback onLogoutTap;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool isOfflineMode;

  const BrowseAppBar({
    Key? key,
    required this.onDrawerOpen,
    required this.onSearchTap,
    required this.onLogoutTap,
    this.showBackButton = false,
    this.onBackPressed,
    this.isOfflineMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = !isOfflineMode
        ? Provider.of<BrowseScreenState>(context, listen: false)
        : null;
    return AppBar(
      backgroundColor: EVColors.appBarBackground,
      foregroundColor: EVColors.appBarForeground,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed,
            )
          : IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onDrawerOpen,
            ),
      title: Text(isOfflineMode ? 'Offline Content' : 'Browse'),
      actions: [
        if (!isOfflineMode && state != null) ...[
          IconButton(
            icon: Icon(state.isInSelectionMode ? Icons.close : Icons.select_all),
            onPressed: () {
              if (state.isInSelectionMode) {
                state.exitSelectionMode();
              } else {
                state.toggleSelectionMode();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onSearchTap,
          ),
        ],
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: onLogoutTap,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
