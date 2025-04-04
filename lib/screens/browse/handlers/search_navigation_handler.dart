import 'package:flutter/material.dart';
import '../../../models/browse_item.dart';
import '../../search/search_screen.dart';

class SearchNavigationHandler {
  final BuildContext context;
  final String baseUrl;
  final String authToken;
  final String instanceType;
  final Function(BrowseItem) navigateToFolder;
  final Function(BrowseItem)? openDocument;

  SearchNavigationHandler({
    required this.context,
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    required this.navigateToFolder,
    this.openDocument,
  });

  Future<void> navigateToSearch([String? initialQuery]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          baseUrl: baseUrl,
          authToken: authToken,
          instanceType: instanceType,
          initialQuery: initialQuery,
        ),
      ),
    );

    // Handle the returned search result item
    if (result != null && result is BrowseItem) {
      if (result.type == 'folder' || result.isDepartment) {
        // Navigate to the folder
        navigateToFolder(result);
      } else {
        // Open the document if handler is provided
        if (openDocument != null) {
          openDocument!(result);
        }
      }
    }
  }
}
