import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String initialQuery;
  final Function(String) onSearch;
  final VoidCallback onBack;
  final TextEditingController? searchController;
  
  const SearchAppBar({
    Key? key,
    this.initialQuery = '',
    required this.onSearch,
    required this.onBack,
    this.searchController,
  }) : super(key: key);
  
  @override
  State<SearchAppBar> createState() => _SearchAppBarState();
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SearchAppBarState extends State<SearchAppBar> {
  late TextEditingController _searchController;
  
  @override
  void initState() {
    super.initState();
    _searchController = widget.searchController ?? TextEditingController(text: widget.initialQuery);
  }
  
  @override
  void dispose() {
    // Only dispose if we created the controller internally
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: EVColors.appBarBackground,
      foregroundColor: EVColors.appBarForeground,
      title: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search documents...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () {
              _searchController.clear();
              // If query is already empty, don't trigger search again
              if (widget.initialQuery.isNotEmpty) {
                widget.onSearch('');
              }
            },
          ),
        ),
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSearch,
        autofocus: widget.initialQuery.isEmpty,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: widget.onBack,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => widget.onSearch(_searchController.text),
        ),
      ],
    );
  }
}
