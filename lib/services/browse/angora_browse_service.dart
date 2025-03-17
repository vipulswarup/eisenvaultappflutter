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
      
      // If we're at the root level, get all departments
      if (parent.id == 'root') {
        EVLogger.debug('Fetching all departments');
        url = buildUrl('departments?slim=true&skip=$skipCount&limit=$maxItems');
      } else {
        // Otherwise, get children of the specified folder/department
        final id = parent.id;
        EVLogger.debug('Fetching contents', {
          'id': id, 
          'isDepartment': parent.isDepartment, 
          'type': parent.type,
          'skip': skipCount,
          'limit': maxItems
        });
        
        // Use the appropriate endpoint based on item type
        if (parent.isDepartment) {
          url = buildUrl('departments/$id/children?skip=$skipCount&limit=$maxItems');
        } else {
          // Use folders endpoint for regular folders, not files
          url = buildUrl('folders/$id/children?skip=$skipCount&limit=$maxItems');
        }
      }
      
      EVLogger.debug('Making API request', {'url': url});
      
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
        'documentCount': items.where((item) => item.type == 'document').length
      });
      
      return items;
    } catch (e) {
      EVLogger.error('Failed to get children', e);
      throw Exception('Failed to get children: ${e.toString()}');
    }
  }
/// Maps an Angora API response item to a BrowseItem object
BrowseItem _mapAngoraBrowseItem(Map<String, dynamic> item) {
  // Log more detailed properties for debugging
  EVLogger.debug('Mapping item', {
    'id': item['id'],
    'name': item['raw_file_name'],
    'is_department': item['is_department'],
    'is_folder': item['is_folder'],
    'file_type': item['file_type'],
    'content_type': item['content_type'],
    'mime_type': item['mime_type'],
    'extension': item['extension']
  });
  
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
  
  EVLogger.debug('Item type determined', {
    'name': item['raw_file_name'],
    'isFolder': isFolder
  });
  
  return BrowseItem(
    id: item['id'],
    name: item['raw_file_name'] ?? item['name'] ?? 'Unnamed Item',
    type: isFolder ? 'folder' : 'document',
    description: item['description'] ?? '',
    isDepartment: item['is_department'] == true,
    // Format dates appropriately
    modifiedDate: item['updated_at'] ?? item['created_at'] ?? '',
    modifiedBy: item['updated_by_name'] ?? item['created_by_name'] ?? '',
    // Include additional properties that might be useful
    allowableOperations: _getOperationsFromPermissions(item),
  );
}
  /// Extract allowable operations from Angora permissions
  List<String>? _getOperationsFromPermissions(Map<String, dynamic> item) {
    final List<String> operations = [];
    
    // Map Angora permissions to operations
    var permissions = item['permissions'];
    if (permissions != null) {
      if (permissions['can_edit'] == true) operations.add('update');
      if (permissions['can_delete'] == true) operations.add('delete');
      if (permissions['can_view'] == true) operations.add('read');
    }
    
    return operations.isEmpty ? null : operations;
  }
}