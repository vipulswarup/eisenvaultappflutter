import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import '../state/browse_screen_state.dart';

class BrowseNavigation extends StatelessWidget {
  const BrowseNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<BrowseScreenState>(
      builder: (context, state, child) {
        if (state.controller.navigationStack.isEmpty) {
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
                  onTap: () => state.controller.loadDepartments(),
                  child: const Text(
                    'Departments',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                
                // Navigation stack items
                ...List.generate(state.controller.navigationStack.length * 2 - 1, (index) {
                  if (index.isOdd) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    );
                  }
                  
                  final folderIndex = index ~/ 2;
                  final folder = state.controller.navigationStack[folderIndex];
                  final isLast = folderIndex == state.controller.navigationStack.length - 1;
                  
                  return InkWell(
                    onTap: () {
                      if (!isLast) {
                        state.controller.navigateToBreadcrumb(folderIndex);
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
      },
    );
  }
} 