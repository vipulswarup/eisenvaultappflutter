import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import 'search_screen_controller.dart';
import 'widgets/empty_search_results.dart';
import 'widgets/search_app_bar.dart';
import 'widgets/search_loading_indicator.dart';
import 'widgets/search_result_item.dart';
import 'widgets/search_sort_options.dart';

class SearchScreen extends StatefulWidget {
  final String baseUrl;
  final String authToken;
  final String instanceType;
  final String? initialQuery;

  const SearchScreen({
    super.key,
    required this.baseUrl,
    required this.authToken,
    required this.instanceType,
    this.initialQuery,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late SearchScreenController _controller;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controller
    _controller = SearchScreenController(
      baseUrl: widget.baseUrl,
      authToken: widget.authToken,
      instanceType: widget.instanceType,
      onStateChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    
    // Set initial query if provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      // Perform initial search
      _performSearch(widget.initialQuery!);
    }
  }
  
  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    _controller.search(query);
  }
  
  void _clearSearch() {
    _searchController.clear();
    _controller.clearResults();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      appBar: SearchAppBar(
        initialQuery: _searchController.text,
        searchController: _searchController,
        onSearch: _performSearch,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Column(
        children: [
          // Show sort options only when we have results
          if (_controller.hasResults && !_controller.isLoading)
            SearchSortOptions(
              currentSortBy: _controller.sortBy,
              isAscending: _controller.sortAscending,
              onSortChanged: (sortBy, isAscending) {
                _controller.updateSort(sortBy, isAscending);
              },
            ),
          
          // Main content area
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Show loading indicator while searching
    if (_controller.isLoading) {
      return SearchLoadingIndicator(
        searchQuery: _searchController.text,
      );
    }
    
    // Show empty state for initial screen (no search performed yet)
    if (!_controller.hasSearched && _controller.results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Search for documents, folders, or departments',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Show empty results state when search returned no matches
    if (_controller.hasSearched && _controller.results.isEmpty) {
      return EmptySearchResults(
        searchQuery: _searchController.text,
        onClearSearch: _clearSearch,
      );
    }
    
    // Show results list
    return ListView.builder(
      itemCount: _controller.results.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = _controller.results[index];
        return SearchResultItem(
          item: item,
          searchQuery: _searchController.text,
          onTap: () {
            // Return the selected item to the browse screen
            Navigator.of(context).pop(item);
          },
        );
      },
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
