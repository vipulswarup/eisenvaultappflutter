import 'package:eisenvaultappflutter/models/browse_item.dart';

enum SortOption {
  nameAsc,
  nameDesc,
  dateModifiedDesc,
  dateModifiedAsc,
  typeAsc,
  typeDesc,
}

enum FilterType {
  all,
  folders,
  files,
  pdf,
  images,
  documents,
  spreadsheets,
  presentations,
}

class FilterSortOptions {
  final FilterType filterType;
  final SortOption sortOption;
  final String? searchQuery;

  const FilterSortOptions({
    this.filterType = FilterType.all,
    this.sortOption = SortOption.nameAsc,
    this.searchQuery,
  });

  FilterSortOptions copyWith({
    FilterType? filterType,
    SortOption? sortOption,
    String? searchQuery,
  }) {
    return FilterSortOptions(
      filterType: filterType ?? this.filterType,
      sortOption: sortOption ?? this.sortOption,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters {
    return filterType != FilterType.all || (searchQuery != null && searchQuery!.isNotEmpty);
  }
}

class FilterSortService {
  /// Applies filters and sorting to a list of items
  static List<BrowseItem> applyFilterAndSort(
    List<BrowseItem> items,
    FilterSortOptions options,
  ) {
    var filteredItems = List<BrowseItem>.from(items);

    // Apply search filter
    if (options.searchQuery != null && options.searchQuery!.isNotEmpty) {
      final query = options.searchQuery!.toLowerCase();
      filteredItems = filteredItems.where((item) {
        return item.name.toLowerCase().contains(query) ||
            (item.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply type filter
    filteredItems = _applyTypeFilter(filteredItems, options.filterType);

    // Apply sorting
    filteredItems = _applySorting(filteredItems, options.sortOption);

    return filteredItems;
  }

  static List<BrowseItem> _applyTypeFilter(
    List<BrowseItem> items,
    FilterType filterType,
  ) {
    if (filterType == FilterType.all) {
      return items;
    }

    return items.where((item) {
      switch (filterType) {
        case FilterType.folders:
          return item.type == 'folder' || item.isDepartment;
        case FilterType.files:
          return item.type != 'folder' && !item.isDepartment;
        case FilterType.pdf:
          return item.name.toLowerCase().endsWith('.pdf');
        case FilterType.images:
          final ext = item.name.split('.').last.toLowerCase();
          return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
        case FilterType.documents:
          final ext = item.name.split('.').last.toLowerCase();
          return ['doc', 'docx', 'txt', 'rtf'].contains(ext);
        case FilterType.spreadsheets:
          final ext = item.name.split('.').last.toLowerCase();
          return ['xls', 'xlsx', 'csv'].contains(ext);
        case FilterType.presentations:
          final ext = item.name.split('.').last.toLowerCase();
          return ['ppt', 'pptx'].contains(ext);
        default:
          return true;
      }
    }).toList();
  }

  static List<BrowseItem> _applySorting(
    List<BrowseItem> items,
    SortOption sortOption,
  ) {
    final sortedItems = List<BrowseItem>.from(items);

    switch (sortOption) {
      case SortOption.nameAsc:
        sortedItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.nameDesc:
        sortedItems.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOption.dateModifiedDesc:
        sortedItems.sort((a, b) {
          if (a.modifiedDate == null && b.modifiedDate == null) return 0;
          if (a.modifiedDate == null) return 1;
          if (b.modifiedDate == null) return -1;
          try {
            final dateA = DateTime.parse(a.modifiedDate!);
            final dateB = DateTime.parse(b.modifiedDate!);
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });
        break;
      case SortOption.dateModifiedAsc:
        sortedItems.sort((a, b) {
          if (a.modifiedDate == null && b.modifiedDate == null) return 0;
          if (a.modifiedDate == null) return 1;
          if (b.modifiedDate == null) return -1;
          try {
            final dateA = DateTime.parse(a.modifiedDate!);
            final dateB = DateTime.parse(b.modifiedDate!);
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        });
        break;
      case SortOption.typeAsc:
        sortedItems.sort((a, b) {
          // Folders first, then files
          if ((a.type == 'folder' || a.isDepartment) && (b.type != 'folder' && !b.isDepartment)) {
            return -1;
          }
          if ((b.type == 'folder' || b.isDepartment) && (a.type != 'folder' && !a.isDepartment)) {
            return 1;
          }
          // Then sort by name
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case SortOption.typeDesc:
        sortedItems.sort((a, b) {
          // Files first, then folders
          if ((a.type == 'folder' || a.isDepartment) && (b.type != 'folder' && !b.isDepartment)) {
            return 1;
          }
          if ((b.type == 'folder' || b.isDepartment) && (a.type != 'folder' && !a.isDepartment)) {
            return -1;
          }
          // Then sort by name
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }

    return sortedItems;
  }

  static String getSortOptionLabel(SortOption option) {
    switch (option) {
      case SortOption.nameAsc:
        return 'Name (A-Z)';
      case SortOption.nameDesc:
        return 'Name (Z-A)';
      case SortOption.dateModifiedDesc:
        return 'Date Modified (Newest)';
      case SortOption.dateModifiedAsc:
        return 'Date Modified (Oldest)';
      case SortOption.typeAsc:
        return 'Type (Folders First)';
      case SortOption.typeDesc:
        return 'Type (Files First)';
    }
  }

  static String getFilterTypeLabel(FilterType type) {
    switch (type) {
      case FilterType.all:
        return 'All Items';
      case FilterType.folders:
        return 'Folders Only';
      case FilterType.files:
        return 'Files Only';
      case FilterType.pdf:
        return 'PDF Files';
      case FilterType.images:
        return 'Images';
      case FilterType.documents:
        return 'Documents';
      case FilterType.spreadsheets:
        return 'Spreadsheets';
      case FilterType.presentations:
        return 'Presentations';
    }
  }
}

