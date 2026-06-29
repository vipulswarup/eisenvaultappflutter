import 'dart:convert';
import 'dart:typed_data';

import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/services/api/angora/angora_document_service.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';

abstract class DocumentService {
  Future<dynamic> getDocumentContent(BrowseItem document);

  Future<Uint8List?> getDocumentPreview(BrowseItem document);
}

class AlfrescoDocumentService implements DocumentService {
  final String baseUrl;
  final String authToken;

  AlfrescoDocumentService(this.baseUrl, this.authToken);

  Map<String, String> get _authHeaders => {
        'Authorization': ' $authToken',
      };

  @override
  Future<dynamic> getDocumentContent(BrowseItem document) async {
    try {
      final nodeId = document.id;
      final contentUrl =
          '$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$nodeId/content';

      final response = await http.get(
        Uri.parse(contentUrl),
        headers: _authHeaders,
      );

      if (response.statusCode != 200) {
        EVLogger.error('Failed to download document', {
          'statusCode': response.statusCode,
        });
        throw Exception('Failed to download document: ${response.statusCode}');
      }

      return response.bodyBytes;
    } catch (e) {
      EVLogger.error('Error getting document content', e);
      throw Exception('Error getting document content: ${e.toString()}');
    }
  }

  @override
  Future<Uint8List?> getDocumentPreview(BrowseItem document) async {
    try {
      final nodeId = document.id;
      final renditionUrl =
          '$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$nodeId/renditions/pdf/content';
      final createUrl =
          '$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$nodeId/renditions';

      Future<http.Response> fetchPdf() {
        return http.get(Uri.parse(renditionUrl), headers: _authHeaders);
      }

      var response = await fetchPdf();
      if (response.statusCode == 404) {
        await http.post(
          Uri.parse(createUrl),
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'id': 'pdf'}),
        );

        for (var attempt = 0; attempt < 5; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          response = await fetchPdf();
          if (response.statusCode == 200) {
            break;
          }
        }
      }

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }

      EVLogger.debug('Alfresco PDF preview unavailable', {
        'nodeId': nodeId,
        'statusCode': response.statusCode,
      });
      return null;
    } catch (e) {
      EVLogger.error('Error getting Alfresco document preview', e);
      return null;
    }
  }
}

class AngoraDocumentServiceAdapter implements DocumentService {
  final AngoraDocumentService _angoraService;

  AngoraDocumentServiceAdapter(this._angoraService);

  @override
  Future<dynamic> getDocumentContent(BrowseItem document) async {
    try {
      final bytes = await _angoraService.downloadDocument(document.id);
      return bytes;
    } catch (e) {
      EVLogger.error('Error getting Angora document content', e);
      throw Exception('Error getting document content: ${e.toString()}');
    }
  }

  @override
  Future<Uint8List?> getDocumentPreview(BrowseItem document) async {
    try {
      return await _angoraService.downloadDocumentPreview(document.id);
    } catch (e) {
      EVLogger.error('Error getting Angora document preview', e);
      return null;
    }
  }
}

class DocumentServiceFactory {
  static DocumentService getService(
    String instanceType,
    String baseUrl,
    String authToken, {
    AngoraBaseService? angoraBaseService,
    TokenRefreshCallback? tokenRefreshCallback,
  }) {
    if (instanceType == 'Classic' || instanceType == 'Alfresco') {
      return AlfrescoDocumentService(baseUrl, authToken);
    } else if (instanceType == 'Angora') {
      final resolvedBaseService =
          angoraBaseService ?? AngoraBaseService(baseUrl);
      if (resolvedBaseService.getToken() == null) {
        resolvedBaseService.setToken(authToken);
      }
      if (tokenRefreshCallback != null) {
        resolvedBaseService.setTokenRefreshCallback(tokenRefreshCallback);
      }
      final angoraService = AngoraDocumentService(resolvedBaseService);
      return AngoraDocumentServiceAdapter(angoraService);
    }

    throw Exception('Document service not implemented for $instanceType');
  }
}
