import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:provider/provider.dart';
import '../state/browse_screen_state.dart';

class BrowseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onDrawerOpen;
  final VoidCallback onSearchTap;
  final VoidCallback onLogoutTap;

  const BrowseAppBar({
    Key? key,
    required this.onDrawerOpen,
    required this.onSearchTap,
    required this.onLogoutTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<BrowseScreenState>(
      builder: (context, state, child) {
        final bool isAtRoot = state.controller?.currentFolder == null || 
                            state.controller?.currentFolder?.id == 'root';
        
        return AppBar(
          title: Text(state.isOffline ? 'Offline Mode' : 'Departments'),
          backgroundColor: EVColors.appBarBackground,
          foregroundColor: EVColors.appBarForeground,
          leading: isAtRoot
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: onDrawerOpen,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (state.controller?.navigationStack.isEmpty ?? true) {
                    state.controller?.loadDepartments();
                  } else if (state.controller?.navigationStack.length == 1) {
                    state.controller?.loadDepartments();
                  } else {
                    final parentIndex = state.controller?.navigationStack.length ?? 0 - 2;
                    state.controller?.navigateToBreadcrumb(parentIndex);
                  }
                },
              ),
          actions: [
            // Selection mode actions
            if (state.isInSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Select All',
                onPressed: () {
                  // Replace the missing selectAll method with direct implementation
                  if (state.isControllerInitialized) {
                    for (var item in state.controller?.items ?? []) {
                      if (!state.selectedItems.contains(item.id)) {
                        state.toggleItemSelection(item.id);
                      }
                    }
                  }
                },
              ),
            ],
            
            // Toggle selection mode
            if (!state.isOffline && (state.controller?.items.isNotEmpty ?? false))
              IconButton(
                icon: Icon(state.isInSelectionMode ? Icons.close : Icons.checklist),
                onPressed: state.toggleSelectionMode,
              ),
              
            // Show selected items count
            if (state.isInSelectionMode && state.selectedItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Text(
                    '${state.selectedItems.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
            // Search button (only in online mode)
            if (!state.isOffline)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: onSearchTap,
              ),
              
            // Logout button
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: onLogoutTap,
            ),
          ],
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 