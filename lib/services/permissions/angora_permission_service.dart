import 'dart:convert';
import 'package:eisenvaultappflutter/services/permissions/permission_service.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;

/// Implementation of PermissionService for Angora API
/// Handles all permission-related operations including caching
class AngoraPermissionService extends AngoraBaseService implements PermissionService {
  /// Cache for storing node permissions to avoid redundant API calls
  final Map<String, List<String>> _permissionsCache = {};
  
  AngoraPermissionService(super.baseUrl, String token) {
    setToken(token);
  }
  
  @override
  Future<bool> hasPermission(String nodeId, String permission) async {
    try {
      // Check cache first for better performance
      if (_permissionsCache.containsKey(nodeId)) {
        final operations = _permissionsCache[nodeId];
        return operations != null && operations.contains(permission);
      }
      
      // Fetch permissions if not in cache
      final permissions = await getNodePermissions(nodeId);
      final operations = extractPermissionsFromDetailedResponse(permissions);
      
      // Cache the operations
      _permissionsCache[nodeId] = operations ?? [];
      
      return operations != null && operations.contains(permission);
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<List<String>?> getPermissions(String nodeId) async {
    
    try {
      // Check cache first
      if (_permissionsCache.containsKey(nodeId)) {
        return _permissionsCache[nodeId];
      }
      
      final permissions = await getNodePermissions(nodeId);
      final operations = extractPermissionsFromDetailedResponse(permissions);
      
      // Cache the operations
      _permissionsCache[nodeId] = operations ?? [];
      
      return operations;
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<List<String>?> extractPermissionsFromItem(Map<String, dynamic> item) async {
    
    final String itemId = item['id'];
    final List<String> operations = [];
    
    // Map Angora permissions to operations
    var permissions = item['permissions'];
    
    // If permissions field is missing or null, fetch from API
    if (permissions == null) {
      try {
        // Use getNodePermissions directly to avoid circular call through getPermissions
        final apiPermissions = await getNodePermissions(itemId);
        
        // Extract and return operations from the API response
        return extractPermissionsFromDetailedResponse(apiPermissions);
      } catch (e) {
        // Continue with the regular extraction logic as fallback
      }
    }
    
    if (permissions != null) {
      // Standard permissions
      if (permissions['can_edit'] == true) operations.add('update');
      if (permissions['can_view'] == true) operations.add('read');
      
      // Add create permission
      if (permissions['can_create_document'] == true || 
          permissions['can_create_folder'] == true ||
          permissions['create_document'] == true ||
          permissions['create_folder'] == true) {
        operations.add('create');
      }
      
      // Add delete permission based on item type
      if (item['is_department'] == true) {
        // For departments
        if (permissions['delete_department'] == true || 
            permissions['can_delete'] == true ||
            permissions['manage_department_permissions'] == true) {
          operations.add('delete');
        }
      } else if (item['is_folder'] == true) {
        // For folders
        if (permissions['delete_folder'] == true || 
            permissions['can_delete'] == true ||
            permissions['manage_folder_permissions'] == true) {
          operations.add('delete');
        }
      } else {
        // For files/documents
        if (permissions['delete_document'] == true || 
            permissions['can_delete'] == true) {
          operations.add('delete');
        }
      }
    } else {
      // Check for alternate permission indicators when permissions field is null
      
      // Check for direct can_delete flag
      if (item['can_delete'] == true) {
        operations.add('delete');
      }
      
      // Check for owner flag - owners can typically delete
      if (item['is_owner'] == true) {
        operations.add('delete');
        operations.add('update');
      }
      
      // Add standard folder permissions by default
      if (item['is_folder'] == true || item['is_department'] == true) {
        operations.add('create');
      }
    }
    
    // If no specific permissions found but it's a folder, default to allowing create
    if (operations.isEmpty && (item['is_folder'] == true || item['is_department'] == true)) {
      operations.add('create');
    }
    
    return operations.isEmpty ? null : operations;
  }
  
  /// Extract operations from detailed permissions response
  List<String>? extractPermissionsFromDetailedResponse(Map<String, dynamic> permissions) {
    
    final List<String> operations = [];
    
    // Map detailed permissions to operations
    if (permissions['view_document'] == true) operations.add('read');
    if (permissions['edit_document_content'] == true || permissions['edit_document'] == true) operations.add('update');
    if (permissions['create_document'] == true || permissions['create_folder'] == true) {
      operations.add('create');
    }
    
    // Add delete operations based on permission type
    if (permissions['delete_department'] == true) operations.add('delete');
    if (permissions['delete_folder'] == true) operations.add('delete');
    if (permissions['delete_document'] == true) operations.add('delete');
    
    // General delete permission
    if (permissions['can_delete'] == true) operations.add('delete');
    
    // Check for direct permission mappings
    if (permissions['can_edit'] == true) operations.add('update');
    if (permissions['can_view'] == true) operations.add('read');
    
    return operations.isEmpty ? null : operations;
  }
  
  /// Fetch node permissions from API based on the Angora API documentation
  Future<Map<String, dynamic>> getNodePermissions(String nodeId) async {
    
    // Use the documented endpoint from angora-get-node-permissions.txt
    final endpoint = 'nodes/$nodeId/permissions';
    final url = buildUrl(endpoint);
    
    // Create headers with required parameters from the API documentation
    final headers = createHeaders(serviceName: 'service-file');
    
    // Add the x-customer-hostname header if not already included
    if (!headers.containsKey('x-customer-hostname')) {
      // Extract hostname from baseUrl or use a configured value
      final uri = Uri.parse(baseUrl);
      final hostname = uri.host;
      
      headers['x-customer-hostname'] = hostname;
    }
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 401) {
        throw Exception('Authentication failed: ${response.statusCode}');
      }
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch node permissions: ${response.statusCode}');
      }
      
      final data = json.decode(response.body);
      
      // Check the expected response format based on the API documentation
      if (data['status'] != 200 || data['data'] == null) {
        throw Exception('Invalid permissions API response format');
      }
      
      // Return the permissions data
      return data['data'];
    } catch (e) {
      rethrow;
    }
  }
  
  /// Invalidate a specific node's permissions in the cache
  void invalidateCache(String nodeId) {
    _permissionsCache.remove(nodeId);
  }
  
  @override
  void clearCache() {
    _permissionsCache.clear();
  }
  
  /// Gets the current size of the permissions cache
  int get cacheSize => _permissionsCache.length;
  
  /// Checks if a node's permissions are currently cached
  bool isCached(String nodeId) => _permissionsCache.containsKey(nodeId);
}
