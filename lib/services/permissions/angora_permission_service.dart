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
  
  AngoraPermissionService(String baseUrl, String token) : super(baseUrl) {
    setToken(token);
    EVLogger.debug('AngoraPermissionService initialized', {'baseUrl': baseUrl});
  }
  
  @override
  Future<bool> hasPermission(String nodeId, String permission) async {
    EVLogger.debug('Checking permission', {
      'nodeId': nodeId, 
      'permission': permission,
      'cacheHit': _permissionsCache.containsKey(nodeId)
    });
    
    try {
      // Check cache first for better performance
      if (_permissionsCache.containsKey(nodeId)) {
        final operations = _permissionsCache[nodeId];
        final hasPermission = operations != null && operations.contains(permission);
        
        EVLogger.debug('Permission check from cache', {
          'nodeId': nodeId,
          'permission': permission,
          'result': hasPermission
        });
        
        return hasPermission;
      }
      
      // Fetch permissions if not in cache
      final permissions = await getNodePermissions(nodeId);
      final operations = extractPermissionsFromDetailedResponse(permissions);
      
      // Cache the operations
      _permissionsCache[nodeId] = operations ?? [];
      
      final hasPermission = operations != null && operations.contains(permission);
      
      EVLogger.debug('Permission check from API', {
        'nodeId': nodeId,
        'permission': permission,
        'result': hasPermission,
        'allPermissions': operations
      });
      
      return hasPermission;
    } catch (e) {
      EVLogger.error('Failed to check permission', {
        'nodeId': nodeId,
        'permission': permission,
        'error': e.toString()
      });
      return false;
    }
  }
  
  @override
  Future<List<String>?> getPermissions(String nodeId) async {
    EVLogger.debug('Getting all permissions', {
      'nodeId': nodeId,
      'cacheHit': _permissionsCache.containsKey(nodeId)
    });
    
    try {
      // Check cache first
      if (_permissionsCache.containsKey(nodeId)) {
        final operations = _permissionsCache[nodeId];
        
        EVLogger.debug('Permissions retrieved from cache', {
          'nodeId': nodeId,
          'permissions': operations
        });
        
        return operations;
      }
      
      final permissions = await getNodePermissions(nodeId);
      final operations = extractPermissionsFromDetailedResponse(permissions);
      
      // Cache the operations
      _permissionsCache[nodeId] = operations ?? [];
      
      EVLogger.debug('Permissions retrieved from API', {
        'nodeId': nodeId,
        'permissions': operations
      });
      
      return operations;
    } catch (e) {
      EVLogger.error('Failed to get permissions', {
        'nodeId': nodeId,
        'error': e.toString()
      });
      return null;
    }
  }
  
  @override
  Future<List<String>?> extractPermissionsFromItem(Map<String, dynamic> item) async {
    final String itemId = item['id'];
    EVLogger.debug('Extracting permissions from item', {
      'itemId': itemId,
      'itemName': item['name'] ?? item['raw_file_name'],
      'hasPermissionsField': item.containsKey('permissions') && item['permissions'] != null
    });
    
    final List<String> operations = [];
    
    // Map Angora permissions to operations
    var permissions = item['permissions'];
    
    // If permissions field is missing or null, fetch from API
    if (permissions == null) {
      EVLogger.debug('Item lacks permissions data, fetching from API', {'itemId': itemId});
      
      try {
        // Use getNodePermissions directly to avoid circular call through getPermissions
        final apiPermissions = await getNodePermissions(itemId);
        
        // Extract and return operations from the API response
        return extractPermissionsFromDetailedResponse(apiPermissions);
      } catch (e) {
        EVLogger.error('Failed to fetch permissions for item', {
          'itemId': itemId,
          'error': e.toString()
        });
        
        // Continue with the regular extraction logic as fallback
        EVLogger.debug('Falling back to default permission logic', {'itemId': itemId});
      }
    }
    
    // The rest of the existing extraction logic remains the same
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
      if (item['can_delete'] == true) operations.add('delete');
      
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
    
    EVLogger.debug('Extracted permissions from item', {
      'itemId': itemId,
      'permissions': operations
    });
    
    return operations.isEmpty ? null : operations;
  }
  
  /// Extract operations from detailed permissions response
  List<String>? extractPermissionsFromDetailedResponse(Map<String, dynamic> permissions) {
    EVLogger.debug('Extracting permissions from detailed response');
    
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
    
    EVLogger.debug('Extracted detailed permissions', {
      'permissions': operations
    });
    
    return operations.isEmpty ? null : operations;
  }
  
  /// Fetch node permissions from API
  /// Tries multiple endpoints to find the correct one for the given node
  Future<Map<String, dynamic>> getNodePermissions(String nodeId) async {
    EVLogger.debug('Fetching node permissions from API', {'nodeId': nodeId});
    
    // Try multiple endpoints to see which one works
    final endpoints = [
      'nodes/$nodeId/permissions',
      'files/$nodeId/permissions',
      'items/$nodeId/permissions',
      'documents/$nodeId/permissions'
    ];
    
    Exception? lastError;
    
    for (final endpoint in endpoints) {
      try {
        final url = buildUrl(endpoint);
        final headers = createHeaders(serviceName: 'service-file');
        
        EVLogger.debug('Trying permission endpoint', {'url': url});
        
        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );
        
        if (response.statusCode != 200) {
          EVLogger.warning('Failed to fetch node permissions', {
            'endpoint': endpoint,
            'statusCode': response.statusCode,
            'body': response.body
          });
          throw Exception('Failed to fetch node permissions: ${response.statusCode}');
        }
        
        final data = json.decode(response.body);
        
        if (data['status'] != 200 || data['data'] == null) {
          EVLogger.warning('Invalid permissions API response', {
            'endpoint': endpoint,
            'response': data
          });
          throw Exception('Invalid permissions API response format');
        }
        
        EVLogger.debug('Successfully retrieved permissions', {
          'endpoint': endpoint,
          'nodeId': nodeId
        });
        
        // If successful, return the data
        return data['data'];
      } catch (e) {
        EVLogger.error('Permission endpoint failed', {
          'endpoint': endpoint,
          'error': e.toString()
        });
        lastError = Exception(e.toString());
        // Continue to next endpoint
      }
    }
    
    // If all endpoints failed, throw the last error
    EVLogger.error('All permission endpoints failed', {'nodeId': nodeId});
    throw lastError ?? Exception('All permission endpoints failed');
  }
  
  /// Invalidate a specific node's permissions in the cache
  void invalidateCache(String nodeId) {
    EVLogger.debug('Invalidating permissions cache', {'nodeId': nodeId});
    _permissionsCache.remove(nodeId);
  }
  
  @override
  void clearCache() {
    EVLogger.debug('Clearing entire permissions cache');
    _permissionsCache.clear();
  }
  
  /// Gets the current size of the permissions cache
  int get cacheSize => _permissionsCache.length;
  
  /// Checks if a node's permissions are currently cached
  bool isCached(String nodeId) => _permissionsCache.containsKey(nodeId);
}
