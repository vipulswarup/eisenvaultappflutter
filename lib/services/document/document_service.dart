import 'dart:io';
import 'dart:typed_data';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

abstract class DocumentService {
  Future<dynamic> getDocumentContent(BrowseItem document);
}

class ClassicDocumentService implements DocumentService {
  final String baseUrl;
  final String authToken;

  ClassicDocumentService(this.baseUrl, this.authToken);

  @override
  Future<dynamic> getDocumentContent(BrowseItem document) async {
    try {
      // Get the content URL for the document
      final nodeId = document.id;
      final contentUrl = '$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$nodeId/content';
      
      EVLogger.debug('Getting document content', {'url': contentUrl});
      
      // Make the request
      final response = await http.get(
        Uri.parse(contentUrl),
        headers: {
          'Authorization': ' $authToken', // Space before token is intentional for Alfresco
        },
      );

      if (response.statusCode != 200) {
        EVLogger.error('Failed to download document', {'statusCode': response.statusCode});
        throw Exception('Failed to download document: ${response.statusCode}');
      }

      // For web platform, return the bytes directly
      if (kIsWeb) {
        EVLogger.debug('Returning content bytes for web platform');
        return response.bodyBytes;
      } 
      
      // For mobile and desktop platforms, save to a temporary file and return the path
      else {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/${document.name}';
        
        EVLogger.debug('Saving content to file', {'path': filePath});
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        return filePath;
      }
    } catch (e) {
      EVLogger.error('Error getting document content', e);
      throw Exception('Error getting document content: ${e.toString()}');
    }
  }
}

class DocumentServiceFactory {
  static DocumentService getService(String instanceType, String baseUrl, String authToken) {
    if (instanceType == 'Classic') {
      return ClassicDocumentService(baseUrl, authToken);
    }
    
    // Will implement Angora service later
    throw Exception('Document service not implemented for $instanceType');
  }
}
