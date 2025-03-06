class BrowseItem {
  final String id;
  final String name;
  final String type; // 'folder', 'document', etc.
  final String? description;
  final String? modifiedDate;
  final String? modifiedBy;
  final bool isDepartment;
  final List<String>? allowableOperations;
  final String? thumbnailUrl;
  final String? documentLibraryId; // Add this field

  BrowseItem({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.modifiedDate,
    this.modifiedBy,
    this.isDepartment = false,
    this.allowableOperations,
    this.thumbnailUrl,
    this.documentLibraryId, // Add to constructor
  });
}