import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String initialQuery;
  final Function(String) onSearch;
  final VoidCallback onBack;
  final TextEditingController? searchController;
  
  const SearchAppBar({
    super.key,
    this.initialQuery = '',
    required this.onSearch,
    required this.onBack,
    this.searchController,
  });
  
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
      iconTheme: const IconThemeData(color: EVColors.appBarForeground),
      titleTextStyle: const TextStyle(
        color: EVColors.appBarForeground,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      actionsIconTheme: const IconThemeData(color: EVColors.appBarForeground),
      title: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search documents...',
          hintStyle: TextStyle(color: EVColors.appBarForeground.withOpacity(0.7)),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: EVColors.appBarForeground),
            onPressed: () {
              _searchController.clear();
              // If query is already empty, don't trigger search again
              if (widget.initialQuery.isNotEmpty) {
                widget.onSearch('');
              }
            },
          ),
        ),
        style: const TextStyle(color: EVColors.appBarForeground),
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
