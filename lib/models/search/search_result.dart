import '../browse_item.dart';

/// Model class for search results
class SearchResult {
  /// List of items matching the search query
  final List<BrowseItem> items;
  
  /// Total count of all results (for pagination)
  final int totalCount;
  
  /// Flag indicating if more results are available
  final bool hasMoreItems;
  
  /// Query string used for the search
  final String query;
  
  SearchResult({
    required this.items,
    required this.totalCount,
    required this.hasMoreItems,
    required this.query,
  });
}
