import 'package:eisenvaultappflutter/services/permissions/permission_service.dart';
import 'package:eisenvaultappflutter/services/api/classic_base_service.dart';

class ClassicPermissionService extends ClassicBaseService implements PermissionService {
  ClassicPermissionService(String baseUrl, String token) : super(baseUrl) {
    setToken(token);
  }
  
  @override
  Future<bool> hasPermission(String nodeId, String permission) async {
    // Implementation for classic repository
    // This is a simplified version using the item's allowableOperations
    final permissions = await getPermissions(nodeId);
    return permissions?.contains(permission) ?? false;
  }
  
  @override
  Future<List<String>?> getPermissions(String nodeId) async {
    // Implementation for classic repository
    // Fetch permissions from API
    try {
      // In a real implementation, this would make an API call
      // For now, returning a basic set of permissions
      return ['read', 'write', 'delete'];
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<List<String>?> extractPermissionsFromItem(Map<String, dynamic> item) async {
    final List<String> operations = [];
    
    // Check for allowableOperations in Classic/Alfresco format
    if (item['allowableOperations'] is List) {
      final allowableOperations = item['allowableOperations'] as List;
      for (final op in allowableOperations) {
        operations.add(op.toString());
      }
    }
    
    return operations.isEmpty ? null : operations;
  }
  
  @override
  void clearCache() {
    // Clear any cached permissions
  }
}
