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
      
      // If this is a department/site, we need to get its documentLibrary
      if (parent.isDepartment) {
        EVLogger.debug('Fetching document library for site', {'siteId': parent.id});
        return _getSiteDocumentLibraryContents(parent.id);
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
          'Authorization': '$authToken',  // No "Basic" prefix added here
        },
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
          'Authorization': '$authToken',  // No "Basic" prefix added here
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
  
  /// Fetches the Document Library contents for a specific site
  Future<List<BrowseItem>> _getSiteDocumentLibraryContents(String siteId) async {
    try {
      EVLogger.debug('Fetching document library for site', {'siteId': siteId});
      
      // First, we need to get the documentLibrary container node ID for this site
      final urlDocLib = Uri.parse(
        '$baseUrl/api/-default-/public/alfresco/versions/1/sites/$siteId/containers/documentLibrary'
      );
      
      final docLibResponse = await http.get(
        urlDocLib,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$authToken',
        },
      );
      
      if (docLibResponse.statusCode != 200) {
        EVLogger.error('Failed to fetch document library', {
          'statusCode': docLibResponse.statusCode,
          'body': docLibResponse.body
        });
        throw Exception('Failed to fetch document library: ${docLibResponse.statusCode}');
      }
      
      final docLibData = json.decode(docLibResponse.body);
      final docLibId = docLibData['entry']['id'];
      
      // Now fetch the contents of the document library
      final urlContents = Uri.parse(
        '$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$docLibId/children?include=path,properties,allowableOperations'
      );
      
      final contentsResponse = await http.get(
        urlContents,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$authToken',
        },
      );
      
      if (contentsResponse.statusCode != 200) {
        EVLogger.error('Failed to fetch document library contents', {
          'statusCode': contentsResponse.statusCode,
          'body': contentsResponse.body
        });
        throw Exception('Failed to fetch document library contents: ${contentsResponse.statusCode}');
      }
      
      final contentsData = json.decode(contentsResponse.body);
      
      if (contentsData['list'] == null || contentsData['list']['entries'] == null) {
        EVLogger.error('Invalid response format for document library contents');
        throw Exception('Invalid response format for document library contents');
      }
      
      final items = (contentsData['list']['entries'] as List)
          .map((entry) => _mapAlfrescoBrowseItem(entry['entry']))
          .toList();
      
      EVLogger.info('Retrieved document library contents', {'count': items.length});
      return items;
    } catch (e) {
      EVLogger.error('Failed to get document library contents', e);
      throw Exception('Failed to get document library contents: ${e.toString()}');
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
}