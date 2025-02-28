import 'dart:convert';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service.dart';
import 'package:http/http.dart' as http;

class AngoraBrowseService implements BrowseService {
  final String baseUrl;
  final String authToken;

  AngoraBrowseService(this.baseUrl, this.authToken);

  @override
  Future<List<BrowseItem>> getChildren(BrowseItem parent) async {
    try {
      // Use different endpoints based on whether we're fetching department or folder contents
      final path = parent.isDepartment
          ? 'departments/${parent.id}/children'
          : 'folders/${parent.id}/children';

      final url = Uri.parse('$baseUrl/$path?action=default');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
          'x-portal': 'web',
          'x-service-name': 'service-file',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['data'] == null) {
        throw Exception('Invalid response format');
      }

      return _mapAngoraBrowseItems(data['data']);
    } catch (e) {
      throw Exception('Failed to get children: ${e.toString()}');
    }
  }

  List<BrowseItem> _mapAngoraBrowseItems(List<dynamic> items) {
    return items.map((item) {
      final bool isFolder = item['objectType'] == 'folder';
      final bool isDepartment = item['objectType'] == 'department';
      
      return BrowseItem(
        id: item['id'].toString(),
        name: item['name'],
        type: isFolder ? 'folder' : 'document',
        description: item['description'],
        modifiedDate: item['modifiedAt'],
        modifiedBy: item['modifiedBy'],
        isDepartment: isDepartment,
      );
    }).toList();
  }
}
