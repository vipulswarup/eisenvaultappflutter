
import '../../models/browse_item.dart';
import '../../services/search/search_service.dart';
import '../../services/search/search_service_factory.dart';
import '../../utils/logger.dart';

class SearchScreenController {
  final String baseUrl;
  final String authToken;
  final String instanceType;
  final Function() onStateChanged;
  
  // State variables
  bool _isLoading = false;
  List<BrowseItem> _results = [];
  bool _hasSearched = false;
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _lastQuery = '';
  
  // Getter for state variables
  bool get isLoading => _isLoading;
  List<BrowseItem> get results => _results;
  bool get hasSearched => _hasSearched;
  bool get hasResults => _results.isNotEmpty;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  
  // Late initialize search service
  late final SearchService _searchService;

  SearchScreenController({
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    required this.onStateChanged,
  }) {
    // Initialize search service - pass parameters as positional arguments
    _searchService = SearchServiceFactory.getService(
      instanceType, 
      baseUrl, 
      authToken
    );
  }
  
  /// Perform a search with the given query
  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    
    _isLoading = true;
    _lastQuery = query;
    onStateChanged();
    
    try {
      final results = await _searchService.search(
        query: query,
        sortBy: _sortBy,
        sortAscending: _sortAscending,
      );
      
      _results = results;
      _hasSearched = true;
      _isLoading = false;
      onStateChanged();
    } catch (e) {
      EVLogger.error('Error performing search', e);
      _isLoading = false;
      _hasSearched = true;
      onStateChanged();
    }
  }
  
  /// Clear search results
  void clearResults() {
    _results = [];
    _hasSearched = false;
    _lastQuery = '';
    onStateChanged();
  }
  
  /// Update sort options and re-run the search
  void updateSort(String sortBy, bool isAscending) {
    _sortBy = sortBy;
    _sortAscending = isAscending;
    
    // Re-run search with new sort options if we've already searched
    if (_hasSearched && _lastQuery.isNotEmpty) {
      search(_lastQuery);
    } else {
      onStateChanged();
    }
  }
  
  /// Dispose of resources
  void dispose() {
    // Clean up any resources if needed
  }
}
