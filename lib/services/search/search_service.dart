import '../../models/browse_item.dart';

/// Defines the contract for search services across different repository types
abstract class SearchService {
  /// Performs a full-text search for the given query text
  /// 
  /// [query] - The search text to find
  /// [maxItems] - Maximum number of results to return
  /// [skipCount] - Number of results to skip (for pagination)
  /// [sortBy] - Property to sort by (name, type, creator, modifiedDate)
  /// [sortAscending] - Whether to sort in ascending order
  /// 
  /// Returns a list of BrowseItem objects matching the search criteria
  Future<List<BrowseItem>> search({
    required String query,
    int maxItems = 50,
    int skipCount = 0,
    String sortBy = 'name',
    bool sortAscending = true,
  });

  /// Checks if the search service is available for the current repository
  /// 
  /// Returns true if search is supported/available
  Future<bool> isSearchAvailable();
}
