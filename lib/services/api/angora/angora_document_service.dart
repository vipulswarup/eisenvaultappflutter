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
  
  /// Get document download link
Future<String> getDocumentDownloadLink(String documentId) async {
  try {
    EVLogger.debug('Fetching document download link', {'documentId': documentId});
    
    final url = _baseService.buildUrl('files/$documentId/download');
    final headers = _baseService.createHeaders(serviceName: _serviceName);
    
    EVLogger.debug('Making download link request', {
      'url': url,
      'headers': headers,
      'serviceName': _serviceName
    });
    
    final response = await http.get(Uri.parse(url), headers: headers);
    
    EVLogger.debug('Download link response', {
      'statusCode': response.statusCode,
      'body': response.body
    });
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get download link: ${response.statusCode}');
    }
    
    final data = json.decode(response.body);
    
    if (data['status'] == 200 && data['data'] != null && data['data']['download_link'] != null) {
      final downloadLink = data['data']['download_link'];
      EVLogger.debug('Retrieved download link', {'link': downloadLink});
      return downloadLink;
    } else {
      throw Exception('Download link not found in response');
    }
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