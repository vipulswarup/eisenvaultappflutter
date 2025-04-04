import 'package:flutter/material.dart';

class EmptySearchResults extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onClearSearch;

  const EmptySearchResults({
    Key? key,
    required this.searchQuery,
    required this.onClearSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found for "$searchQuery"',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try different keywords or check your spelling',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onClearSearch,
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }
}
