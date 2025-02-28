import 'dart:convert';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;

class ClassicBrowseService implements BrowseService {
  final String baseUrl;
  final String authToken;
  
  // Known ID for the "Sites" folder in Alfresco
  static const String sitesNodeId = 'sites';

  ClassicBrowseService(this.baseUrl, this.authToken);

  @override
  Future<List<BrowseItem>> getChildren(BrowseItem parent) async {
    try {
      // If we're at the root level, get Sites folder contents instead
      if (parent.id == 'root') {
        EVLogger.debug('Fetching Sites folder contents instead of root');
        return _getSitesFolderContents();
      }
      
      // Otherwise, get children of the specified folder
      final nodeId = parent.id;
      EVLogger.debug('Fetching contents of folder', {'nodeId': nodeId});
      
      final url = Uri.parse(
        '$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$nodeId/children?include=path,properties,allowableOperations'
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $authToken',
        },
      );

      if (response.statusCode != 200) {
        EVLogger.error('Failed to fetch items', {'statusCode': response.statusCode});
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

      EVLogger.info('Retrieved folder contents', {'count': items.length});
      return items;
    } catch (e) {
      EVLogger.error('Failed to get children', e);
      throw Exception('Failed to get children: ${e.toString()}');
    }
  }

  /// Fetches the contents of the "Sites" folder specifically
  Future<List<BrowseItem>> _getSitesFolderContents() async {
    try {
      EVLogger.debug('Fetching Sites folder contents');
      
      final url = Uri.parse(
        '$baseUrl/api/-default-/public/alfresco/versions/1/sites?skipCount=0&maxItems=100'
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': ' $authToken',
        },
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

      EVLogger.info('Retrieved sites', {'count': sites.length});
      return sites;
    } catch (e) {
      EVLogger.error('Failed to get sites', e);
      throw Exception('Failed to get sites: ${e.toString()}');
    }
  }

  /// Maps an Alfresco API response item to a BrowseItem object
  BrowseItem _mapAlfrescoBrowseItem(Map<String, dynamic> entry) {
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
  }
  
  /// Helper method to get a specific folder by path
  Future<String> _getFolderIdByPath(String path) async {
    try {
      EVLogger.debug('Getting folder ID by path', {'path': path});
      
      final encodedPath = Uri.encodeComponent(path);
      final url = Uri.parse(
        '$baseUrl/api/-default-/public/alfresco/versions/1/nodes/-root-/children?relativePath=$encodedPath'
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $authToken',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get folder by path: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['list'] == null || data['list']['entries'] == null || data['list']['entries'].isEmpty) {
        throw Exception('Folder not found at path: $path');
      }

      final folderId = data['list']['entries'][0]['entry']['id'];
      EVLogger.debug('Found folder ID', {'path': path, 'id': folderId});
      return folderId;
    } catch (e) {
      EVLogger.error('Failed to get folder by path', {'path': path, 'error': e.toString()});
      throw Exception('Failed to get folder by path: ${e.toString()}');
    }
  }
}