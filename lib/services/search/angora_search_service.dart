import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/browse_item.dart';
import '../../utils/logger.dart';
import '../api/angora_base_service.dart';
import 'search_service.dart';

/// Implementation of SearchService for Angora repositories
class AngoraSearchService implements SearchService {
  final AngoraBaseService _angoraService;
  
  AngoraSearchService(this._angoraService);
  
  @override
  Future<List<BrowseItem>> search({
    required String query,
    int maxItems = 50,
    int skipCount = 0,
    String sortBy = 'name',
    bool sortAscending = true,
  }) async {
    try {
      // Map the sortBy parameter to Angora property names
      final String angoraSortProperty = _mapSortByToAngoraProperty(sortBy);
      final String sortDirection = sortAscending ? 'asc' : 'desc';
      
      // Calculate page number from skipCount (Angora uses page-based pagination, 1-based)
      final int page = (skipCount / maxItems).floor() + 1;
      
      // Build the search API URL with properly encoded query parameters
      // Note: Angora uses 'name' parameter (not 'query') and 'page' (not 'skip')
      final baseUrl = _angoraService.buildUrl('search');
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'name': query,
        'limit': maxItems.toString(),
        'page': page.toString(),
        'sort': angoraSortProperty,
        'direction': sortDirection,
      });
      
      // Create headers for the search request
      final headers = _angoraService.createHeaders(serviceName: 'service-search');
      headers['x-portal'] = 'mobile';  // Set mobile portal header
      
      // Log the API call details
      EVLogger.debug('Angora Search API Call', {
        'url': uri.toString(),
        'method': 'GET',
        'name': query,
        'limit': maxItems,
        'page': page,
        'skipCount': skipCount,
        'sort': angoraSortProperty,
        'direction': sortDirection,
        'headers': headers,
      });
      
      final response = await http.get(
        uri,
        headers: headers,
      );
      
      // Log the response details
      EVLogger.debug('Angora Search API Response', {
        'statusCode': response.statusCode,
        'responseBody': response.body,
        'responseHeaders': response.headers,
      });
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Log parsed response data structure
        EVLogger.debug('Angora Search Parsed Response', {
          'responseData': responseData,
          'responseDataType': responseData.runtimeType.toString(),
          'hasData': responseData.containsKey('data'),
          'dataType': responseData['data']?.runtimeType.toString(),
        });
        
        // Check if the response has data and results array
        if (responseData['data'] == null) {
          EVLogger.warning('Angora Search: Response data is null', {
            'responseData': responseData,
          });
          return [];
        }
        
        final data = responseData['data'];
        List<dynamic> results;
        
        // Handle different response structures:
        // 1. When data is a List (empty results or direct array)
        if (data is List) {
          EVLogger.debug('Angora Search: Data is a List (direct results array)', {
            'dataLength': data.length,
          });
          results = data;
        }
        // 2. When data is a Map with a 'results' key (standard structure)
        else if (data is Map) {
          if (data['results'] == null) {
            EVLogger.warning('Angora Search: Results field is null in Map', {
              'data': data,
              'dataKeys': data.keys.toList(),
            });
            return [];
          }
          results = data['results'] as List<dynamic>;
        }
        // 3. Unexpected structure
        else {
          EVLogger.warning('Angora Search: Data has unexpected type', {
            'data': data,
            'dataType': data.runtimeType.toString(),
          });
          return [];
        }
        
        EVLogger.debug('Angora Search Results', {
          'resultsCount': results.length,
          'results': results,
        });
        
        // Convert the search results to BrowseItem objects
        return results.map<BrowseItem>((item) {
          // Determine item type using is_folder, is_file, is_department flags
          final bool isFolder = item['is_folder'] == true;
          final bool isDepartment = item['is_department'] == true;
          
          // Extract permissions (if available)
          List<String> allowableOperations = [];
          if (item['permissions'] != null) {
            if (item['permissions'] is List) {
              allowableOperations = List<String>.from(item['permissions']);
            } else if (item['permissions'] is Map) {
              allowableOperations = _extractPermissionsFromMap(item['permissions']);
            }
          }
          
          return BrowseItem(
            id: item['id'] ?? '',
            name: item['raw_file_name'] ?? item['name'] ?? '',
            type: isFolder ? 'folder' : 'document',
            description: item['description'] ?? '',
            modifiedDate: item['updated_at'] ?? item['created_at'],
            modifiedBy: item['updated_by'] ?? item['created_by'],
            isDepartment: isDepartment,
            allowableOperations: allowableOperations,
          );
        }).toList();
      } else {
        EVLogger.error('Angora Search request failed', {
          'statusCode': response.statusCode,
          'responseBody': response.body,
          'responseHeaders': response.headers,
        });
        throw Exception('Search failed with status ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error during search operation', e, stackTrace);
      throw Exception('Search operation failed: $e');
    }
  }
  
  @override
  Future<bool> isSearchAvailable() async {
    try {
      // Check if the search API is available by making a simple request
      final baseUrl = _angoraService.buildUrl('search');
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'name': 'test',
        'limit': '1',
        'page': '1',
      });
      
      final headers = _angoraService.createHeaders(serviceName: 'service-search');
      headers['x-portal'] = 'mobile';
      
      final response = await http.get(
        uri,
        headers: headers,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      EVLogger.warning('Search service is not available', {'error': e.toString()});
      return false;
    }
  }
  
  /// Maps the generic sort property to Angora-specific property
  String _mapSortByToAngoraProperty(String sortBy) {
    switch (sortBy.toLowerCase()) {
      case 'name':
        return 'name';
      case 'type':
        return 'type';
      case 'creator':
        return 'createdBy';
      case 'modifieddate':
      case 'date':
        return 'updatedAt';
      default:
        return 'name';
    }
  }
  
  /// Helper method to extract permissions from a map structure
  List<String> _extractPermissionsFromMap(Map<String, dynamic> permissionsMap) {
    List<String> permissions = [];
    
    if (permissionsMap['create'] == true) permissions.add('create');
    if (permissionsMap['read'] == true) permissions.add('read');
    if (permissionsMap['update'] == true) permissions.add('update');
    if (permissionsMap['delete'] == true) permissions.add('delete');
    
    return permissions;
  }
}
