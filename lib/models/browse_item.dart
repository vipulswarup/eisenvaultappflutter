class BrowseItem {
  final String id;
  final String name;
  final String type;
  final String? description;
  final String? modifiedDate;
  final String? modifiedBy;
  final bool isDepartment;
  final List<String>? allowableOperations;
  final String? thumbnailUrl;
  final String? documentLibraryId;
  //final bool canWrite;

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
    this.documentLibraryId,
    //this.canWrite = false,
  });
  
  // Add this helper method to check for write permission
  bool get canWrite {
    if (allowableOperations == null) return false;
    
    // Alfresco typically uses these permission strings
    return allowableOperations!.any((op) => 
      op == 'create' || 
      op == 'update' || 
      op == 'write' || 
      op == 'delete' ||
      op == 'all');
  }
}