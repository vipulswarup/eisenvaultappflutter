import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:flutter/material.dart';

/// Displays breadcrumb navigation for folder hierarchy.
class BreadcrumbNavigation extends StatelessWidget {
  final List<BrowseItem> navigationStack;
  final BrowseItem? currentFolder;
  final VoidCallback onRootTap;
  final Function(int) onBreadcrumbTap;

  const BreadcrumbNavigation({
    super.key,
    required this.navigationStack,
    required this.currentFolder,
    required this.onRootTap,
    required this.onBreadcrumbTap,
  });

  @override
  Widget build(BuildContext context) {
    const breadcrumbText = Colors.black87;
    const breadcrumbSeparator = Colors.grey;
    const breadcrumbCurrentText = Colors.blue;

    // Check if the current folder is the same as the last item in the navigation stack
    final bool isDuplicateFolder = currentFolder != null &&
        navigationStack.isNotEmpty &&
        navigationStack.last.id == currentFolder!.id;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: onRootTap,
            child: const Text(
              'Departments',
              style: TextStyle(
                color: breadcrumbText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (int i = 0; i < navigationStack.length; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: breadcrumbSeparator,
              ),
            ),
            InkWell(
              onTap: () => onBreadcrumbTap(i),
              child: Text(
                navigationStack[i].name,
                style: const TextStyle(
                  color: breadcrumbText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          // Only show the current folder if it's not a duplicate of the last navigation stack item
          if (currentFolder != null && currentFolder!.id != 'root' && !isDuplicateFolder) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: breadcrumbSeparator,
              ),
            ),
            Text(
              currentFolder?.name ?? '',
              style: const TextStyle(
                color: breadcrumbCurrentText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}