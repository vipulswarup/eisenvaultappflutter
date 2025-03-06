import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:flutter/material.dart';

/// Displays breadcrumb navigation for folder hierarchy
class BreadcrumbNavigation extends StatelessWidget {
  final List<BrowseItem> navigationStack;
  final BrowseItem? currentFolder;
  final Function() onRootTap;
  final Function(int) onBreadcrumbTap;

  const BreadcrumbNavigation({
    Key? key,
    required this.navigationStack,
    required this.currentFolder,
    required this.onRootTap,
    required this.onBreadcrumbTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final breadcrumbText = Colors.black87;
    final breadcrumbSeparator = Colors.grey;
    final breadcrumbCurrentText = Colors.blue;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: onRootTap,
            child: const Text(
              'Root',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (int i = 0; i < navigationStack.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                style: TextStyle(
                  color: breadcrumbText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (currentFolder != null && currentFolder!.id != 'root') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: breadcrumbSeparator,
              ),
            ),
            Text(
              currentFolder?.name ?? '',
              style: TextStyle(
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
