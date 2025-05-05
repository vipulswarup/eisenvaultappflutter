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
      
      // Build the search API URL with query parameters
      final searchUrl = _angoraService.buildUrl(
        'search?query=$query'
        '&limit=$maxItems'
        '&skip=$skipCount'
        '&sort=$angoraSortProperty'
        '&direction=$sortDirection'
      );
      
      
      
      // Create headers for the search request
      final headers = _angoraService.createHeaders(serviceName: 'service-search');
      headers['x-portal'] = 'mobile';  // Set mobile portal header
      
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Check if the response has data and results array
        if (responseData['data'] == null || 
            responseData['data']['results'] == null) {
          return [];
        }
        
        final results = responseData['data']['results'] as List<dynamic>;
        
        
        
        // Convert the search results to BrowseItem objects
        return results.map<BrowseItem>((item) {
          // Determine item type
          final bool isFolder = item['type'] == 'folder';
          final bool isDepartment = item['type'] == 'department';
          
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
            name: item['name'] ?? '',
            type: isFolder ? 'folder' : 'document',
            description: item['description'],
            modifiedDate: item['updatedAt'] ?? item['createdAt'],
            modifiedBy: item['updatedBy'] ?? item['createdBy'],
            isDepartment: isDepartment,
            allowableOperations: allowableOperations,
          );
        }).toList();
      } else {
        EVLogger.error('Search request failed', {
          'statusCode': response.statusCode,
          'response': response.body,
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
      final searchUrl = _angoraService.buildUrl('search?query=test&limit=1');
      
      final headers = _angoraService.createHeaders(serviceName: 'service-search');
      headers['x-portal'] = 'mobile';
      
      final response = await http.get(
        Uri.parse(searchUrl),
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
