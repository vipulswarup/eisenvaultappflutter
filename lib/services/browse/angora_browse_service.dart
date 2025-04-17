import 'dart:convert';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/permissions/permission_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;

/// Implementation of BrowseService for Angora repositories
class AngoraBrowseService extends AngoraBaseService implements BrowseService {
  final PermissionService _permissionService;
  
  /// Constructor initializes the service with base URL, token and permission service
  AngoraBrowseService(
    String baseUrl, 
    String token,
    this._permissionService
  ) : super(baseUrl) {
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
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      // Check if we got a valid response
      if (data['status'] != 200 || data['data'] == null) {
        throw Exception('Invalid API response format');
      }

      final itemsData = data['data'] as List;
      final items = <BrowseItem>[];
      
      // Map all items WITHOUT fetching permissions
      for (final itemData in itemsData) {
        final mappedItem = _mapAngoraBrowseItemWithoutPermissions(itemData);
        items.add(mappedItem);
      }
      
      return items;
    } catch (e) {
      throw Exception('Failed to get children: ${e.toString()}');
    }
  }

 

  /// Maps an Angora API response item to a BrowseItem object without permission checking
  BrowseItem _mapAngoraBrowseItemWithoutPermissions(Map<String, dynamic> item) {
    // Same logic as before for determining folder type, etc.
    bool isFolder = false;
    
    if (item['is_department'] == true || item['is_folder'] == true) {
      isFolder = true;
    } 
    else if (item['file_type'] != null || 
                item['content_type'] != null || 
                item['mime_type'] != null || 
                item['extension'] != null) {
      isFolder = false;
    }
    else if (item['can_have_children'] == true) {
      isFolder = true;
    }
    else if (item['parent_department_id'] != null && item['is_department'] != false) {
      isFolder = true;
    }
    
    // Set default permissions for folders and departments
    List<String>? operations;
    if (isFolder || item['is_department'] == true) {
      operations = ['create', 'update', 'delete'];
    }
    
    
    
    return BrowseItem(
      id: item['id'],
      name: item['raw_file_name'] ?? item['name'] ?? 'Unnamed Item',
      type: isFolder ? 'folder' : 'document',
      description: item['description'] ?? '',
      isDepartment: item['is_department'] == true,
      // Format dates appropriately
      modifiedDate: item['updated_at'] ?? item['created_at'] ?? '',
      modifiedBy: item['updated_by_name'] ?? item['created_by_name'] ?? '',
      allowableOperations: operations,
    );
  }

  /// Fetches permissions for a single item on demand
  @override
  Future<List<String>?> fetchPermissionsForItem(String itemId) async {
    try {
      return await _permissionService.getPermissions(itemId);
    } catch (e) {
      EVLogger.error('Error fetching permissions', {'itemId': itemId, 'error': e.toString()});
      return null;
    }
  }

  /// Gets detailed information about a specific item by ID
  @override
  Future<BrowseItem?> getItemDetails(String itemId) async {
    try {
      // For Angora, we need to determine if this is a file or folder/department
      // Try both endpoints and use the first successful response
      
      // First try as a file
      try {
        final fileUrl = buildUrl('files/$itemId');
        final fileHeaders = createHeaders(serviceName: 'service-file');
        
        final fileResponse = await http.get(
          Uri.parse(fileUrl),
          headers: fileHeaders,
        );
        
        if (fileResponse.statusCode == 200) {
          final data = json.decode(fileResponse.body);
          
          if (data['status'] == 200 && data['data'] != null) {
            // Convert file response to BrowseItem
            return _mapAngoraBrowseItemWithoutPermissions(data['data']);
          }
        }
      } catch (e) {
        // Item not found as file, continue to try as folder
      }
      
      // Then try as a folder
      try {
        final folderUrl = buildUrl('folders/$itemId');
        final folderHeaders = createHeaders(serviceName: 'service-file');
        
        final folderResponse = await http.get(
          Uri.parse(folderUrl),
          headers: folderHeaders,
        );
        
        if (folderResponse.statusCode == 200) {
          final data = json.decode(folderResponse.body);
          
          if (data['status'] == 200 && data['data'] != null) {
            // Convert folder response to BrowseItem
            return _mapAngoraBrowseItemWithoutPermissions(data['data']);
          }
        }
      } catch (e) {
        // Item not found as folder, continue to try as department
      }
      
      // Finally try as a department
      try {
        final deptUrl = buildUrl('departments/$itemId');
        final deptHeaders = createHeaders(serviceName: 'service-file');
        
        final deptResponse = await http.get(
          Uri.parse(deptUrl),
          headers: deptHeaders,
        );
        
        if (deptResponse.statusCode == 200) {
          final data = json.decode(deptResponse.body);
          
          if (data['status'] == 200 && data['data'] != null) {
            // Convert department response to BrowseItem
            final item = _mapAngoraBrowseItemWithoutPermissions(data['data']);
            // Ensure department flag is set
            return BrowseItem(
              id: item.id,
              name: item.name,
              type: item.type,
              description: item.description,
              modifiedDate: item.modifiedDate,
              modifiedBy: item.modifiedBy,
              isDepartment: true, // Ensure this is set for departments
              allowableOperations: item.allowableOperations,
            );
          }
        }
      } catch (e) {
        EVLogger.warning('Item not found as department', {'itemId': itemId, 'error': e.toString()});
      }
      
      // If we've tried all endpoints and found nothing, return null
      EVLogger.warning('Item not found in any Angora endpoint', {'itemId': itemId});
      return null;
    } catch (e) {
      EVLogger.error('Error getting Angora item details', {
        'itemId': itemId,
        'error': e.toString(),
      });
      
      // Rethrow to be handled by caller
      rethrow;
    }
  }
}
