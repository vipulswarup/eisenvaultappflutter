import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import '../state/browse_screen_state.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

class BrowseNavigation extends StatelessWidget {
  const BrowseNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<BrowseScreenState>(
      builder: (context, state, child) {
        // Check if controller is initialized
        if (!state.isControllerInitialized) {
          return const SizedBox.shrink();
        }
        
        try {
          // If navigationStack is empty, don't show anything
          if (state.controller?.navigationStack.isEmpty ?? true) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Root item
                  InkWell(
                    onTap: () => state.controller?.loadDepartments(),
                    child: const Text(
                      'Departments',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  
                  // Navigation stack items
                  ...List.generate((state.controller?.navigationStack.length ?? 0) * 2 - 1, (index) {
                    if (index.isOdd) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                      );
                    }
                    
                    final folderIndex = index ~/ 2;
                    // Safely access the folder
                    if (folderIndex >= (state.controller?.navigationStack.length ?? 0)) {
                      return const SizedBox.shrink();
                    }
                    
                    final folder = state.controller?.navigationStack[folderIndex];
                    if (folder == null) {
                      return const SizedBox.shrink();
                    }
                    
                    final isLast = folderIndex == (state.controller?.navigationStack.length ?? 0) - 1;
                    
                    return InkWell(
                      onTap: () {
                        if (!isLast) {
                          state.controller?.navigateToBreadcrumb(folderIndex);
                        }
                      },
                      child: Text(
                        folder.name,
                        style: TextStyle(
                          fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                          color: isLast ? EVColors.primaryBlue : Colors.black87,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        } catch (e) {
          // Log the error and return an empty widget
          EVLogger.error('Error in BrowseNavigation', e);
          return const SizedBox.shrink();
        }
      },
    );
  }
}
