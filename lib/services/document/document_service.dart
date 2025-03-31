import 'dart:io';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:eisenvaultappflutter/services/api/angora/angora_document_service.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';

abstract class DocumentService {
  Future<dynamic> getDocumentContent(BrowseItem document);
}

class AlfrescoDocumentService implements DocumentService {
  final String baseUrl;
  final String authToken;

  AlfrescoDocumentService(this.baseUrl, this.authToken);

  @override
  Future<dynamic> getDocumentContent(BrowseItem document) async {
    try {
      // Get the content URL for the document
      final nodeId = document.id;
      final contentUrl = '$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$nodeId/content';
      
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
  
        return response.bodyBytes;
      } 
      
      // For mobile and desktop platforms, save to a temporary file and return the path
      else {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/${document.name}';
        
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

class AngoraDocumentServiceAdapter implements DocumentService {
  final AngoraDocumentService _angoraService;
  
  AngoraDocumentServiceAdapter(this._angoraService);
  
  @override
  Future<dynamic> getDocumentContent(BrowseItem document) async {
    try {
      // Get document content using Angora service - directly downloads now
      final bytes = await _angoraService.downloadDocument(document.id);
      
      // For web platform, return the bytes directly
      if (kIsWeb) {
  
        return bytes;
      } 
      
      // For mobile and desktop platforms, save to a temporary file and return the path
      else {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/${document.name}';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        
        return filePath;
      }
    } catch (e) {
      EVLogger.error('Error getting Angora document content', e);
      throw Exception('Error getting document content: ${e.toString()}');
    }
  }
}
class DocumentServiceFactory {
  static DocumentService getService(
    String instanceType, 
    String baseUrl, 
    String authToken,
    {AngoraBaseService? angoraBaseService}
  ) {
    if (instanceType == 'Classic' || instanceType == 'Alfresco') {
      return AlfrescoDocumentService(baseUrl, authToken);
    } else if (instanceType == 'Angora') {
      if (angoraBaseService == null) {
        throw Exception('AngoraBaseService is required for Angora document service');
      }
      final angoraService = AngoraDocumentService(angoraBaseService);
      return AngoraDocumentServiceAdapter(angoraService);
    }
    
    throw Exception('Document service not implemented for $instanceType');
  }
}