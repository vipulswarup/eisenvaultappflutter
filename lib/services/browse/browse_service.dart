import 'package:eisenvaultappflutter/models/browse_item.dart';

/// Abstract interface for browse services across different repository types
abstract class BrowseService {
  /// Fetches children items of a parent folder or department
  /// 
  /// [parent] - The parent item whose children to fetch
  /// [skipCount] - Number of items to skip (for pagination)
  /// [maxItems] - Maximum number of items to return per page
  Future<List<BrowseItem>> getChildren(
    BrowseItem parent, {
    int skipCount = 0,
    int maxItems = 25,
  });
  
  /// Fetches permissions for a specific item on demand
  Future<List<String>?> fetchPermissionsForItem(String itemId);
}
