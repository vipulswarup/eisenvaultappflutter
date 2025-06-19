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

    const BrowseItem({
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
    });

    /// Returns true if the user has write/create/update/delete/all permissions.
    bool get canWrite {
      if (allowableOperations == null) return false;
      return allowableOperations!.any((op) =>
          op == 'create' ||
          op == 'update' ||
          op == 'write' ||
          op == 'delete' ||
          op == 'all');
    }

    /// Returns true if the user has delete/all permissions.
    bool get canDelete {
      if (allowableOperations == null) return false;
      return allowableOperations!.any((op) =>
          op == 'delete' ||
          op == 'all');
    }

    /// Returns true if this is a system folder that should not be renamed or deleted.
    /// System folders include departments, documentLibrary, and dataLists.
    bool get isSystemFolder {
      // Departments are system folders
      if (isDepartment) return true;
      
      // documentLibrary is a system folder (identified by name or folderId)
      if (name == 'documentLibrary') return true;
      
      // dataLists is a system folder (identified by name)
      if (name == 'dataLists') return true;
      
      return false;
    }
  }