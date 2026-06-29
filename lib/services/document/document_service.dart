import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/services/api/angora/angora_document_service.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/api/classic_base_service.dart';
import 'package:eisenvaultappflutter/utils/http_utils.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

abstract class DocumentService {
  Future<dynamic> getDocumentContent(BrowseItem document);
}

class AlfrescoDocumentService implements DocumentService {
  final ClassicBaseService _baseService;

  AlfrescoDocumentService(String baseUrl, String authToken)
      : _baseService = ClassicBaseService(baseUrl) {
    _baseService.setToken(authToken);
  }

  @override
  Future<dynamic> getDocumentContent(BrowseItem document) async {
    try {
      final nodeId = document.id;
      final contentUrl = _baseService.buildUrl(
        'api/-default-/public/alfresco/versions/1/nodes/$nodeId/content',
      );

      final response = await getWithTimeout(
        Uri.parse(contentUrl),
        headers: {
          ..._baseService.createHeaders(),
          'Accept': 'application/octet-stream, */*',
        },
        timeout: downloadRequestTimeout,
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
