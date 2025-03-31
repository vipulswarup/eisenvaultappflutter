abstract class PermissionService {
  /// Checks if a specific permission exists for a node
  Future<bool> hasPermission(String nodeId, String permission);
  
  /// Get all permissions for a specific node
  Future<List<String>?> getPermissions(String nodeId);
  
  /// Extract permissions from a browse item
  /// If permissions data is not in the item, fetch it from the API
  Future<List<String>?> extractPermissionsFromItem(Map<String, dynamic> item);
  
  /// Clear any cached permissions
  void clearCache();
}
