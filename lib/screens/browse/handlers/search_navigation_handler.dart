import 'package:flutter/material.dart';
import '../../../models/browse_item.dart';
import '../../../screens/search/search_screen.dart';

class SearchNavigationHandler {
  final BuildContext context;
  final String baseUrl;
  final String authToken;
  final String instanceType;
  final Function(BrowseItem) navigateToFolder;

  SearchNavigationHandler({
    required this.context,
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    required this.navigateToFolder,
  });

  /// Navigate to the search screen
  Future<void> navigateToSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          baseUrl: baseUrl,
          authToken: authToken,
          instanceType: instanceType,
        ),
      ),
    );
    
    // If a folder or department was selected from search results, navigate to it
    if (result is BrowseItem) {
      if (result.type == 'folder' || result.isDepartment) {
        navigateToFolder(result);
      }
    }
  }
}
