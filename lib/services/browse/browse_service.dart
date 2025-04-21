import 'package:eisenvaultappflutter/models/browse_item.dart';

/// Abstract interface for browse services across different repository types.
abstract class BrowseService {
  /// Fetches children items of a parent folder or department.
  Future<List<BrowseItem>> getChildren(
    BrowseItem parent, {
    int skipCount = 0,
    int maxItems = 25,
  });

  /// Fetches permissions for a specific item on demand.
  Future<List<String>?> fetchPermissionsForItem(String itemId);

  /// Fetches details for a specific item by ID.
  /// This is useful for getting the latest metadata of an item
  /// without knowing its parent, particularly for sync operations.
  /// Returns the item's details or null if not found.
  Future<BrowseItem?> getItemDetails(String itemId);
}