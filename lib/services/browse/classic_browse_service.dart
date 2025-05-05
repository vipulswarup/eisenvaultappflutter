import 'dart:convert';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/services/api/classic_base_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;

/// Implementation of BrowseService for Classic/Alfresco repositories
class ClassicBrowseService implements BrowseService {
  final String baseUrl;
  final String authToken;
  final ClassicBaseService _baseService;
  
  // Known ID for the "Sites" folder in Alfresco
  static const String sitesNodeId = 'sites';

  ClassicBrowseService(this.baseUrl, this.authToken) : _baseService = ClassicBaseService(baseUrl) {
    _baseService.setToken(authToken);
  }

  @override
  Future<List<BrowseItem>> getChildren(
    BrowseItem parent, {
    int skipCount = 0,
    int maxItems = 25,
  }) async {
    try {
      // If we're at the root level, get Sites folder contents instead
      if (parent.id == 'root') {
        return _getSitesFolderContents(skipCount: skipCount, maxItems: maxItems);
      }
      
      // If this is a department/site, fetch its containers (including documentLibrary)
      if (parent.isDepartment) {
        return _getSiteContainers(parent.id, skipCount: skipCount, maxItems: maxItems);
      }
      
      // Otherwise, get children of the specified folder
      final nodeId = parent.id;
      
      final url = Uri.parse(
        _baseService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$nodeId/children?include=path,properties,allowableOperations&skipCount=$skipCount&maxItems=$maxItems')
      );

      final response = await http.get(
        url,
        headers: _baseService.createHeaders(),
      );

      if (response.statusCode != 200) {
        EVLogger.error('Failed to fetch items', {
          'statusCode': response.statusCode, 
          'body': response.body
        });
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['list'] == null || data['list']['entries'] == null) {
        EVLogger.error('Invalid response format');
        throw Exception('Invalid response format');
      }

      final items = (data['list']['entries'] as List)
          .map((entry) => _mapAlfrescoBrowseItem(entry['entry']))
          .toList();

      
      return items;
    } catch (e) {
      EVLogger.error('Failed to get children', e);
      throw Exception('Failed to get children: ${e.toString()}');
    }
  }

  /// Fetches the contents of the "Sites" folder specifically
  Future<List<BrowseItem>> _getSitesFolderContents({
    int skipCount = 0,
    int maxItems = 25,
  }) async {
    
    final start = DateTime.now();
    try {
      final url = Uri.parse(
        _baseService.buildUrl('api/-default-/public/alfresco/versions/1/sites?skipCount=$skipCount&maxItems=$maxItems')
      );

      final response = await http.get(
        url,
        headers: _baseService.createHeaders(),
      );

      if (response.statusCode != 200) {
        EVLogger.error('Failed to fetch sites', {'statusCode': response.statusCode});
        throw Exception('Failed to fetch sites: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['list'] == null || data['list']['entries'] == null) {
        EVLogger.error('Invalid response format for sites');
        throw Exception('Invalid response format for sites');
      }

      // Map the sites to BrowseItem objects
      final sites = (data['list']['entries'] as List).map((entry) {
        final site = entry['entry'];
        return BrowseItem(
          id: site['id'],
          name: site['title'] ?? site['id'],
          type: 'folder',
          description: site['description'],
          isDepartment: true, // Mark sites as departments
          modifiedDate: site['modifiedAt'],
          modifiedBy: site['visibility'], // Using visibility as a placeholder
        );
      }).toList();

      
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      
      return sites;
    } catch (e) {
      EVLogger.error('Failed to get sites', e);
      rethrow;
    }
  }
  
  /// Fetches the containers (e.g. documentLibrary) for a specific site
  Future<List<BrowseItem>> _getSiteContainers(
    String siteId, {
    int skipCount = 0,
    int maxItems = 25,
  }) async {
    try {
      final url = Uri.parse(
        _baseService.buildUrl('api/-default-/public/alfresco/versions/1/sites/$siteId/containers?skipCount=$skipCount&maxItems=$maxItems')
      );
      final response = await http.get(
        url,
        headers: _baseService.createHeaders(),
      );
      if (response.statusCode != 200) {
        EVLogger.error('Failed to fetch site containers', {
          'statusCode': response.statusCode,
          'body': response.body
        });
        throw Exception('Failed to fetch site containers: ${response.statusCode}');
      }
      final data = json.decode(response.body);
      if (data['list'] == null || data['list']['entries'] == null) {
        EVLogger.error('Invalid response format for site containers');
        throw Exception('Invalid response format for site containers');
      }
      final containers = <BrowseItem>[];
      for (final entry in data['list']['entries']) {
        final container = entry['entry'];
        // Fetch permissions for this container
        List<String>? allowableOperations;
        try {
          final permUrl = Uri.parse(
            _baseService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/${container['id']}?include=allowableOperations')
          );
          final permResponse = await http.get(
            permUrl,
            headers: _baseService.createHeaders(),
          );
          if (permResponse.statusCode == 200) {
            final permData = json.decode(permResponse.body);
            if (permData['entry'] != null && permData['entry']['allowableOperations'] != null) {
              allowableOperations = List<String>.from(permData['entry']['allowableOperations']);
            }
          }
        } catch (e) {
          EVLogger.error('Failed to fetch permissions for container', {
            'containerId': container['id'],
            'error': e.toString(),
          });
        }
        containers.add(BrowseItem(
          id: container['id'],
          name: container['folderId'] ?? container['id'],
          type: 'folder',
          description: container['title'] ?? '',
          isDepartment: false,
          modifiedDate: container['modifiedAt'],
          modifiedBy: container['modifiedByUser']?['displayName'],
          allowableOperations: allowableOperations,
        ));
      }
      
      return containers;
    } catch (e) {
      EVLogger.error('Failed to get site containers', e);
      throw Exception('Failed to get site containers: ${e.toString()}');
    }
  }

  /// Maps an Alfresco API response item to a BrowseItem object
  BrowseItem _mapAlfrescoBrowseItem(Map<String, dynamic> entry) {
    // Extract allowable operations
    List<String>? allowableOperations;
    if (entry['allowableOperations'] != null) {
      allowableOperations = List<String>.from(entry['allowableOperations']);
    } else if (entry['permissions'] != null) {
      // Fallback to permissions if allowableOperations is not present
      if (entry['permissions'] is List) {
        allowableOperations = List<String>.from(entry['permissions']);
      }
    }

    return BrowseItem(
      id: entry['id'],
      name: entry['name'],
      type: entry['isFolder'] == true ? 'folder' : 'document',
      description: entry['properties']?['cm:description'],
      modifiedDate: entry['modifiedAt'],
      modifiedBy: entry['modifiedByUser']?['displayName'],
      isDepartment: entry['nodeType'] == 'st:site',
      allowableOperations: allowableOperations,
    );
  }

  @override
  Future<List<String>?> fetchPermissionsForItem(String itemId) async {
    try {
      // For Classic/Alfresco, we need to fetch the node to get its allowable operations
      final url = Uri.parse(
        _baseService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$itemId?include=allowableOperations')
      );

      final response = await http.get(
        url,
        headers: _baseService.createHeaders(),
      );

      if (response.statusCode != 200) {
        EVLogger.error('Failed to fetch item permissions', {
          'statusCode': response.statusCode, 
          'body': response.body
        });
        return null;
      }

      final data = json.decode(response.body);
      
      if (data['entry'] == null || data['entry']['allowableOperations'] == null) {
        return null;
      }

      // Extract and return the allowable operations
      return List<String>.from(data['entry']['allowableOperations']);
    } catch (e) {
      EVLogger.error('Error fetching permissions for item', {
        'itemId': itemId,
        'error': e.toString()
      });
      return null;
    }
  }

  /// Gets detailed information about a specific item by its ID
  @override
  Future<BrowseItem?> getItemDetails(String itemId) async {
    try {
      // First try without aspects and with minimal parameters
      final url = Uri.parse(
        _baseService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$itemId')
      );
      
      // Create headers with explicit Accept header for JSON
      final headers = Map<String, String>.from(_baseService.createHeaders());
      headers['Accept'] = 'application/json';
      
      
      
      final response = await http.get(
        url,
        headers: headers,
      );
      
      // Log the response for debugging
      
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final entry = data['entry'];
        
        // Map the response to a BrowseItem
        return BrowseItem(
          id: entry['id'],
          name: entry['name'],
          type: entry['isFolder'] == true ? 'folder' : 'document',
          description: entry['properties']?['cm:description'],
          modifiedDate: entry['modifiedAt'],
          modifiedBy: entry['modifiedByUser']?['displayName'],
          isDepartment: entry['nodeType'] == 'st:site',
          allowableOperations: entry['allowableOperations'] != null
              ? List<String>.from(entry['allowableOperations'])
              : null,
        );
      } else if (response.statusCode == 500) {
        // Try the fallback method for any 500 error
        EVLogger.warning('Got 500 error, trying fallback method', {
          'itemId': itemId,
          'error': response.body,
        });
        return await _getItemDetailsFallback(itemId);
      } else {
        EVLogger.error('Failed to get item details', {
          'itemId': itemId,
          'statusCode': response.statusCode,
          'response': response.body,
        });
        
        throw Exception('Failed to get item details: ${response.statusCode}');
      }
    } catch (e) {
      EVLogger.error('Error getting item details', {
        'itemId': itemId,
        'error': e.toString(),
      });
      
      // Try fallback method for any error
      try {
        return await _getItemDetailsFallback(itemId);
      } catch (fallbackError) {
        EVLogger.error('Fallback method also failed', {
          'itemId': itemId,
          'error': fallbackError.toString(),
        });
        throw Exception('Failed to get item details: Item not found or inaccessible');
      }
    }
  }
  
  /// Fallback method for getting item details when the main method fails
  Future<BrowseItem?> _getItemDetailsFallback(String itemId) async {
    try {
      // Try an even simpler URL with no query parameters
      final url = Uri.parse(
        _baseService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$itemId/content')
      );
      
      final headers = Map<String, String>.from(_baseService.createHeaders());
      headers['Accept'] = '*/*';
      
      // First check if we can access the content
      final response = await http.head(
        url,
        headers: headers,
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        // If we can access the content, the item exists. Get basic metadata
        final metadataUrl = Uri.parse(
          _baseService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$itemId')
        );
        
        final metadataResponse = await http.get(
          metadataUrl,
          headers: {'Accept': 'application/json', ...headers},
        );
        
        if (metadataResponse.statusCode == 200) {
          final data = json.decode(metadataResponse.body);
          final entry = data['entry'];
          
          // Create a basic BrowseItem with minimal information
          return BrowseItem(
            id: entry['id'],
            name: entry['name'],
            type: entry['isFolder'] == true ? 'folder' : 'document',
            modifiedDate: entry['modifiedAt'],
            modifiedBy: entry['modifiedByUser']?['displayName'],
          );
        }
      }
      
      EVLogger.error('Fallback method failed to get item details', {
        'itemId': itemId,
        'statusCode': response.statusCode,
      });
      return null;
    } catch (e) {
      EVLogger.error('Error in fallback method', {
        'itemId': itemId,
        'error': e.toString(),
      });
      return null;
    }
  }
}
