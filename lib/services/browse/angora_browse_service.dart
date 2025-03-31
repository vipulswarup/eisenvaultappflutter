import 'dart:convert';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/permissions/permission_service.dart';
import 'package:http/http.dart' as http;

class AngoraBrowseService extends AngoraBaseService implements BrowseService {
  final PermissionService _permissionService;
  
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

      final items = (data['data'] as List)
          .map((item) => _mapAngoraBrowseItem(item))
          .toList();
      
      return items;
    } catch (e) {
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
    
    // Use the permission service to extract permissions
    List<String>? operations = _permissionService.extractPermissionsFromItem(item);
    
    return BrowseItem(
      id: item['id'],
      name: item['raw_file_name'] ?? item['name'] ?? 'Unnamed Item',
      type: isFolder ? 'folder' : 'document',
      description: item['description'] ?? '',
      isDepartment: item['is_department'] == true,
      // Format dates appropriately
      modifiedDate: item['updated_at'] ?? item['created_at'] ?? '',
      modifiedBy: item['updated_by_name'] ?? item['created_by_name'] ?? '',
      // Include permissions from the permission service
      allowableOperations: operations,
    );
  }

  Future<BrowseItem> getItemWithDetailedPermissions(BrowseItem item) async {
    try {
      // Get detailed permissions from API
      final permissions = await _permissionService.getPermissions(item.id);
      
      // Create new item with updated permissions
      return BrowseItem(
        id: item.id,
        name: item.name,
        type: item.type,
        description: item.description,
        isDepartment: item.isDepartment,
        modifiedDate: item.modifiedDate,
        modifiedBy: item.modifiedBy,
        allowableOperations: permissions,
      );
    } catch (e) {
      // If API call fails, return original item
      return item;
    }
  }
}
