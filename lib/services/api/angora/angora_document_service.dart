import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../angora_base_service.dart';
import '../../../utils/logger.dart';

class AngoraDocumentService {
  final AngoraBaseService _baseService;
  
  static const _serviceName = 'service-file';
  // Public CORS proxy (for development only)
  // TODO
  static const _corsProxyUrl = 'https://corsproxy.io/?';
  
  AngoraDocumentService(this._baseService);
  
  Future<String> getDocumentDownloadLink(String documentId) async {
    try {
      EVLogger.debug('Fetching document download link', {'documentId': documentId});
      
      final url = _baseService.buildUrl('files/$documentId/download');
      final headers = {
        ..._baseService.createHeaders(serviceName: _serviceName),
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en',
        'referer': 'https://binod.angorastage.in/nodes'  // Adding referer header
      };
      
      EVLogger.debug('Making download link request', {
        'url': url,
        'headers': headers
      });
      
      final response = await http.get(Uri.parse(url), headers: headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final downloadLink = data['data']['download_link'];
        EVLogger.debug('Retrieved download link', {'link': downloadLink});
        return downloadLink;
      }
      
      throw Exception('Failed to get download link: ${response.statusCode}');
    } catch (error) {
      EVLogger.error('Failed to get document download link', error);
      throw Exception('Failed to get document download link: $error');
    }
  }  
  /// Download document for preview
  Future<Uint8List> downloadDocument(String documentId) async {
    try {
      EVLogger.debug('Downloading document', {'documentId': documentId});
      
      // First get the document download link
      final downloadLink = await getDocumentDownloadLink(documentId);
      EVLogger.debug('Got download link', {'link': downloadLink});
      
      // For web platform, use a CORS proxy
      final effectiveUrl = kIsWeb 
          ? '$_corsProxyUrl${Uri.encodeComponent(downloadLink)}'
          : downloadLink;
      
      EVLogger.debug('Using URL for download', {'url': effectiveUrl});
      
      // Now download the actual file
      final response = await http.get(Uri.parse(effectiveUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
      
      EVLogger.debug('Document downloaded successfully', 
          {'documentId': documentId, 'size': response.bodyBytes.length});
      
      return response.bodyBytes;
    } catch (error) {
      EVLogger.error('Failed to download document', error);
      throw Exception('Failed to download document: $error');
    }
  }
}