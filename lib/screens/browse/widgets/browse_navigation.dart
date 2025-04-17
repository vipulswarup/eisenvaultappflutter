import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import '../browse_screen_controller.dart';

class BrowseNavigation extends StatelessWidget {
  const BrowseNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<BrowseScreenController>(
      builder: (context, controller, child) {
        // Add debug logging to see the navigation state
        EVLogger.debug('BrowseNavigation build', {
          'currentFolder': controller.currentFolder?.name,
          'navigationStackSize': controller.navigationStack.length,
          'navigationStack': controller.navigationStack.map((item) => item.name).toList(),
        });

        // Only show breadcrumb if we're in a folder (not at root)
        if (controller.currentFolder == null || controller.currentFolder?.id == 'root') {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Home/Root button - style it like a link
                InkWell(
                  onTap: () {
                    controller.loadDepartments();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.home, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Home',
                        style: TextStyle(color: EVColors.primaryBlue), // Use the same color as other links
                      ),
                    ],
                  ),
                ),
                
                // Show navigation stack items
                ...List.generate(controller.navigationStack.length, (index) {
                  return Row(
                    children: [
                      const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                      InkWell(
                        onTap: () {
                          controller.navigateToBreadcrumb(index);
                        },
                        child: Text(
                          controller.navigationStack[index].name,
                          style: TextStyle(color: EVColors.primaryBlue),
                        ),
                      ),
                    ],
                  );
                }),
                
                // Current folder (last item in breadcrumb)
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                Text(
                  controller.currentFolder?.name ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
