import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/browse_item.dart';
import '../../utils/logger.dart';
import '../api/classic_base_service.dart';
import 'search_service.dart';

/// Implementation of SearchService for Classic/Alfresco repositories
class ClassicSearchService implements SearchService {
  final ClassicBaseService _classicService;
  
  ClassicSearchService(this._classicService);
  
  @override
  Future<List<BrowseItem>> search({
    required String query,
    int maxItems = 50,
    int skipCount = 0,
    String sortBy = 'name',
    bool sortAscending = true,
  }) async {
    try {
      // Map the sortBy parameter to Alfresco property names
      final String alfrescoSortProperty = _mapSortByToAlfrescoProperty(sortBy);
      final String sortDirection = sortAscending ? 'ASC' : 'DESC';
      
      // Build the search API URL
      final searchUrl = _classicService.buildUrl(
        'api/-default-/public/search/versions/1/search'
      );
      
      // Create the search query payload
      final payload = {
        'query': {
          'query': 'cm:name:*$query* OR cm:content:*$query* OR cm:description:*$query*',
          'language': 'afts'
        },
        'paging': {
          'maxItems': maxItems,
          'skipCount': skipCount
        },
        'sort': [
          {
            'type': 'FIELD',
            'field': alfrescoSortProperty,
            'ascending': sortAscending
          }
        ],
        'include': ['allowableOperations', 'properties', 'aspectNames']
      };
      
      
      
      final response = await http.post(
        Uri.parse(searchUrl),
        headers: _classicService.createHeaders(),
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final list = responseData['list'];
        final entries = list['entries'] as List<dynamic>;
        
        EVLogger.info('Search returned ${entries.length} results');
        
        // Convert the search results to BrowseItem objects
        return entries.map<BrowseItem>((entry) {
          final nodeData = entry['entry'];
          
          final String nodeId = nodeData['id'] ?? '';
          final String name = nodeData['name'] ?? '';
          final bool isFolder = nodeData['isFolder'] == true;
          final String? modifiedDate = nodeData['modifiedAt'];
          final Map<String, dynamic>? modifiedByUser = nodeData['modifiedByUser'];
          final String? modifiedBy = modifiedByUser != null 
              ? modifiedByUser['displayName'] ?? modifiedByUser['id']
              : null;
          
          // Extract allowable operations
          List<String> allowableOperations = [];
          if (nodeData['allowableOperations'] != null) {
            allowableOperations = List<String>.from(nodeData['allowableOperations']);
          }
          
          // Check if it's a site/department
          bool isDepartment = false;
          if (nodeData['aspectNames'] != null) {
            final aspectNames = List<String>.from(nodeData['aspectNames']);
            isDepartment = aspectNames.contains('st:site');
          }
          
          return BrowseItem(
            id: nodeId,
            name: name,
            type: isFolder ? 'folder' : 'document',
            modifiedDate: modifiedDate,
            modifiedBy: modifiedBy,
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
      final searchUrl = _classicService.buildUrl(
        'api/-default-/public/search/versions/1/search'
      );
      
      final testPayload = {
        'query': {
          'query': 'TYPE:"cm:content"',
          'language': 'afts'
        },
        'paging': {
          'maxItems': 1,
          'skipCount': 0
        }
      };
      
      final response = await http.post(
        Uri.parse(searchUrl),
        headers: _classicService.createHeaders(),
        body: jsonEncode(testPayload),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      EVLogger.warning('Search service is not available', {'error': e.toString()});
      return false;
    }
  }
  
  /// Maps the generic sort property to Alfresco-specific property
  String _mapSortByToAlfrescoProperty(String sortBy) {
    switch (sortBy.toLowerCase()) {
      case 'name':
        return 'cm:name';
      case 'type':
        return 'cm:content.mimetype';
      case 'creator':
        return 'cm:creator';
      case 'modifieddate':
      case 'date':
        return 'cm:modified';
      default:
        return 'cm:name';
    }
  }
}
