import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/filter_sort/filter_sort_service.dart';
import 'package:flutter/material.dart';

class FilterSortDialog extends StatefulWidget {
  final FilterSortOptions initialOptions;

  const FilterSortDialog({
    super.key,
    required this.initialOptions,
  });

  @override
  State<FilterSortDialog> createState() => _FilterSortDialogState();
}

class _FilterSortDialogState extends State<FilterSortDialog> {
  late FilterSortOptions _options;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions;
    _searchController.text = widget.initialOptions.searchQuery ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EVColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EVColors.appBarBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Filter & Sort',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search filter
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search',
                        hintText: 'Search by name...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _options = _options.copyWith(searchQuery: '');
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _options = _options.copyWith(
                            searchQuery: value.isEmpty ? null : value,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Filter type section
                    const Text(
                      'Filter by Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: EVColors.textDefault,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FilterType.values.map((type) {
                        final isSelected = _options.filterType == type;
                        return FilterChip(
                          label: Text(FilterSortService.getFilterTypeLabel(type)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _options = _options.copyWith(filterType: type);
                            });
                          },
                          selectedColor: EVColors.buttonBackground.withOpacity(0.3),
                          checkmarkColor: EVColors.buttonBackground,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    
                    // Sort option section
                    const Text(
                      'Sort by',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: EVColors.textDefault,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...SortOption.values.map((option) {
                      return RadioListTile<SortOption>(
                        title: Text(FilterSortService.getSortOptionLabel(option)),
                        value: option,
                        groupValue: _options.sortOption,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _options = _options.copyWith(sortOption: value);
                            });
                          }
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            // Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: EVColors.textGrey.withOpacity(0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(FilterSortOptions());
                    },
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EVColors.buttonBackground,
                      foregroundColor: EVColors.buttonForeground,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(_options);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

