import 'dart:convert';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;

class AngoraBrowseService extends AngoraBaseService implements BrowseService {
  
  AngoraBrowseService(String baseUrl, String token) : super(baseUrl) {
    setToken(token);
  }

  @override
  Future<List<BrowseItem>> getChildren(
    BrowseItem parent, {
    int skipCount = 0,
    int maxItems = 25,
  }) async {
    try {
      final String url;
      
      // Calculate page number for Angora API (which uses page/limit instead of skip/max)
      // Page is 1-based in Angora API
      final int page = (skipCount / maxItems).floor() + 1;
      final int limit = maxItems;
      
      // If we're at the root level, get all departments
      if (parent.id == 'root') {
        
        // For departments, we might not need pagination or it might use different parameters
        url = buildUrl('departments?slim=true');
      } else {
        // Otherwise, get children of the specified folder/department
        final id = parent.id;
        
        
        // Use the appropriate endpoint based on item type
        if (parent.isDepartment) {
          // According to angora-node-children-operations.txt, Angora uses page/limit for pagination
          url = buildUrl('departments/$id/children?page=$page&limit=$limit');
        } else {
          // Use folders endpoint for regular folders, not files
          // According to API docs, folders also use page/limit
          url = buildUrl('folders/$id/children?page=$page&limit=$limit');
        }
      }
      
      
      
      // Use the headers from AngoraBaseService
      final headers = createHeaders(serviceName: 'service-file');
      
    
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200) {
        EVLogger.error('Failed to fetch items', {
          'statusCode': response.statusCode,
          'body': response.body
        });
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      // Log the full API response structure

      
      // Check if we got a valid response
      if (data['status'] != 200 || data['data'] == null) {
        EVLogger.error('Invalid API response', {'response': data});
        throw Exception('Invalid API response format');
      }

      final items = (data['data'] as List)
          .map((item) => _mapAngoraBrowseItem(item))
          .toList();

      EVLogger.info('Retrieved items', {
        'count': items.length,
        'folderCount': items.where((item) => item.type == 'folder').length,
        'documentCount': items.where((item) => item.type == 'document').length,
        'page': page,
        'limit': limit
      });
      
      return items;
    } catch (e) {
      EVLogger.error('Failed to get children', e);
      throw Exception('Failed to get children: ${e.toString()}');
    }
  }

  /// Maps an Angora API response item to a BrowseItem object
  BrowseItem _mapAngoraBrowseItem(Map<String, dynamic> item) {
    
    // Improved folder detection logic
    bool isFolder = false;
    
    // First check clear folder indicators
    if (item['is_department'] == true || item['is_folder'] == true) {
      isFolder = true;
    } 
    // Then check clear file indicators - if any of these exist, it's a file
    else if (item['file_type'] != null || 
                item['content_type'] != null || 
                item['mime_type'] != null || 
                item['extension'] != null) {
      isFolder = false;
    }
    // For items without clear indicators, check if it can have children
    else if (item['can_have_children'] == true) {
      isFolder = true;
    }
    // Finally, check if it has special folder/department properties
    else if (item['parent_department_id'] != null && item['is_department'] != false) {
      isFolder = true;
    }
    
    // Extract permissions
    List<String>? operations = _getOperationsFromPermissions(item);
    

    
    return BrowseItem(
      id: item['id'],
      name: item['raw_file_name'] ?? item['name'] ?? 'Unnamed Item',
      type: isFolder ? 'folder' : 'document',
      description: item['description'] ?? '',
      isDepartment: item['is_department'] == true,
      // Format dates appropriately
      modifiedDate: item['updated_at'] ?? item['created_at'] ?? '',
      modifiedBy: item['updated_by_name'] ?? item['created_by_name'] ?? '',
      // Include permissions
      allowableOperations: operations,
    );
  }

  /// Extract allowable operations from Angora permissions
  List<String>? _getOperationsFromPermissions(Map<String, dynamic> item) {
    final List<String> operations = [];
    
    // Map Angora permissions to operations
    var permissions = item['permissions'];
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
      // NEW CODE: Check for alternate permission indicators when permissions field is null
      
      // Check for direct can_delete flag
      if (item['can_delete'] == true) {
        operations.add('delete');
      }
      
      // Check for owner flag - owners can typically delete
      if (item['is_owner'] == true) {
        operations.add('delete');
        operations.add('update');
      }
      
      // Add standard folder permissions by default (can be adjusted based on your security model)
      if (item['is_folder'] == true || item['is_department'] == true) {
        operations.add('create');
        // You might want to conditionally add 'delete' here based on your security model
      }
    }
    
    // If no specific permissions found but it's a folder, default to allowing create
    // This is a fallback for cases where permissions might not be explicitly set
    if (operations.isEmpty && (item['is_folder'] == true || item['is_department'] == true)) {
      operations.add('create');
    }
    

    
    return operations.isEmpty ? null : operations;
  }

  // Add a cache for node permissions
  final Map<String, List<String>> _permissionsCache = {};

  // Add a method to fetch permissions for a specific node
  Future<Map<String, dynamic>> getNodePermissions(String nodeId) async {
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
        
        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );
        

        
        if (response.statusCode != 200) {
          EVLogger.error('Failed to fetch node permissions', {
            'statusCode': response.statusCode,
            'body': response.body
          });
          throw Exception('Failed to fetch node permissions: ${response.statusCode}');
        }
        
        final data = json.decode(response.body);
        
        if (data['status'] != 200 || data['data'] == null) {
          EVLogger.error('Invalid permissions API response', {'response': data});
          throw Exception('Invalid permissions API response format');
        }
        
        // If successful, return the data
        return data['data'];
      } catch (e) {
        EVLogger.error('ENDPOINT FAILED: $endpoint - $e');
        lastError = Exception(e.toString());
        // Continue to next endpoint
      }
    }
    
    // If all endpoints failed, throw the last error
    throw lastError ?? Exception('All permission endpoints failed');
  }

  // Add a method to extract operations from detailed permissions
  List<String>? _getOperationsFromDetailedPermissions(Map<String, dynamic> permissions) {
    final List<String> operations = [];
    
    // Map detailed permissions to operations
    if (permissions['view_document'] == true) operations.add('read');
    if (permissions['edit_document_content'] == true) operations.add('update');
    if (permissions['create_document'] == true || permissions['create_folder'] == true) {
      operations.add('create');
    }
    
    // Add delete operations based on permission type
    if (permissions['delete_department'] == true) operations.add('delete');
    if (permissions['delete_folder'] == true) operations.add('delete');
    if (permissions['delete_document'] == true) operations.add('delete');
    

    
    return operations.isEmpty ? null : operations;
  }

  // Add a method to check if an item has a specific permission
  Future<bool> hasPermission(String nodeId, String permission) async {
    try {

      
      // Check cache first
      if (_permissionsCache.containsKey(nodeId)) {
        final operations = _permissionsCache[nodeId];
        final hasPermission = operations != null && operations.contains(permission);
        

        
        return hasPermission;
      }
      
      // Fetch permissions if not in cache
      final permissions = await getNodePermissions(nodeId);
      final operations = _getOperationsFromDetailedPermissions(permissions);
      
      // Cache the operations
      _permissionsCache[nodeId] = operations ?? [];
      
      final hasPermission = operations != null && operations.contains(permission);
    
      
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
}
