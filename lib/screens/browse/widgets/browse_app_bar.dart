import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/screens/browse/browse_screen_controller.dart';

class BrowseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onDrawerOpen;
  final VoidCallback onSearchTap;
  final VoidCallback onLogoutTap;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const BrowseAppBar({
    Key? key,
    required this.onDrawerOpen,
    required this.onSearchTap,
    required this.onLogoutTap,
    this.showBackButton = false,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the controller to check if we should show the back button
    final controller = Provider.of<BrowseScreenController>(context, listen: false);
    
    // Determine if we should show the back button
    final shouldShowBackButton = showBackButton || 
        (controller.currentFolder != null && controller.currentFolder!.id != 'root') ||
        controller.navigationStack.isNotEmpty;
    
    return AppBar(
      backgroundColor: EVColors.appBarBackground,
      foregroundColor: EVColors.appBarForeground,
      title: const Text('EisenVault'),
      leading: shouldShowBackButton
          ? BackButton(
              color: EVColors.appBarForeground,
              onPressed: onBackPressed,
            )
          : IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onDrawerOpen,
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: onSearchTap,
        ),
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
