import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import '../browse_screen_controller.dart';

class BrowseNavigation extends StatelessWidget {
  final Function() onHomeTap;
  final Function(int) onBreadcrumbTap;
  final String? currentFolderName;
  final List<dynamic> navigationStack;
  final dynamic currentFolder;

  const BrowseNavigation({
    Key? key,
    required this.onHomeTap,
    required this.onBreadcrumbTap,
    required this.currentFolderName,
    required this.navigationStack,
    required this.currentFolder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show breadcrumb if we're in a folder (not at root)
    if (currentFolder == null || currentFolder?.id == 'root') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: EVColors.browseNavBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Home/Root button - style it like a link
            InkWell(
              onTap: onHomeTap,
              child: Row(
                children: [
                  const Icon(Icons.home, size: 16, color: EVColors.browseNavText),
                  const SizedBox(width: 4),
                  Text(
                    'Home',
                    style: TextStyle(color: EVColors.browseNavText),
                  ),
                ],
              ),
            ),
            ...List.generate(navigationStack.length, (index) {
              return Row(
                children: [
                  const Icon(Icons.chevron_right, size: 16, color: EVColors.browseNavChevron),
                  InkWell(
                    onTap: () => onBreadcrumbTap(index),
                    child: Text(
                      navigationStack[index].name,
                      style: TextStyle(color: EVColors.browseNavText),
                    ),
                  ),
                ],
              );
            }),
            const Icon(Icons.chevron_right, size: 16, color: EVColors.browseNavChevron),
            Text(
              currentFolderName ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, color: EVColors.browseNavCurrentText),
            ),
          ],
        ),
      ),
    );  }
}
