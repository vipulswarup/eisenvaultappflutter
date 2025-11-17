import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../angora_base_service.dart';
import '../../../utils/logger.dart';


class AngoraDocumentService {
  final AngoraBaseService _baseService;
  
  static const _serviceName = 'service-file';
  // Use a reliable CORS proxy for web PDF downloads
  static const _corsProxyUrl = 'https://api.allorigins.win/raw?url=';
  
  AngoraDocumentService(this._baseService);
  
  Future<String> getDocumentDownloadLink(String documentId) async {
    try {
      final url = _baseService.buildUrl('files/$documentId/download');
      final headers = {
        ..._baseService.createHeaders(serviceName: _serviceName),
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en',
        'referer': 'https://binod.angorastage.in/nodes'
      };
      
      EVLogger.debug('Requesting download link', {
        'url': url,
        'documentId': documentId,
      });
      
      final response = await http.get(Uri.parse(url), headers: headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Check for both snake_case and camelCase field names
        final downloadLink = data['data']?['download_link'] ?? data['data']?['downloadLink'];
        
        if (downloadLink == null || downloadLink.toString().isEmpty) {
          EVLogger.error('Download link is null or empty', {
            'response': response.body,
            'data': data,
            'dataKeys': data['data']?.keys?.toList(),
          });
          throw Exception('Download link is missing from API response');
        }
        
        EVLogger.debug('Download link received', {
          'downloadLink': downloadLink.toString().substring(0, downloadLink.toString().length > 100 ? 100 : downloadLink.toString().length),
        });
        
        return downloadLink.toString();
      }
      
      EVLogger.error('Failed to get download link', {
        'statusCode': response.statusCode,
        'response': response.body,
      });
      throw Exception('Failed to get download link: ${response.statusCode}');
    } catch (error) {
      EVLogger.error('Failed to get document download link', error);
      throw Exception('Failed to get document download link: $error');
    }
  }  
  
  Future<Uint8List> downloadDocument(String documentId) async {
    try {
      // Try to get download link first
      String? downloadLink;
      try {
        downloadLink = await getDocumentDownloadLink(documentId);
      } catch (e) {
        EVLogger.debug('Could not get download link, falling back to download-stream endpoint', {
          'error': e.toString(),
        });
        // Fall back to download-stream endpoint
        return await _downloadFromStream(documentId);
      }
      
      // Validate and normalize the download link
      String effectiveUrl;
      try {
        final uri = Uri.parse(downloadLink);
        
        // If the URI doesn't have a host, it's a relative path - combine with base URL
        if (uri.host.isEmpty) {
          final baseUri = Uri.parse(_baseService.baseUrl);
          effectiveUrl = Uri(
            scheme: baseUri.scheme,
            host: baseUri.host,
            port: baseUri.port,
            path: downloadLink.startsWith('/') ? downloadLink : '/$downloadLink',
          ).toString();
          EVLogger.debug('Converted relative download link to absolute', {
            'original': downloadLink,
            'effective': effectiveUrl,
          });
        } else {
          effectiveUrl = downloadLink;
        }
      } catch (e) {
        EVLogger.error('Invalid download link format, falling back to download-stream', {
          'downloadLink': downloadLink,
          'error': e.toString(),
        });
        // Fall back to download-stream endpoint
        return await _downloadFromStream(documentId);
      }
      
      // For web, use CORS proxy
      if (kIsWeb) {
        effectiveUrl = '$_corsProxyUrl${Uri.encodeComponent(effectiveUrl)}';
      }
      
      EVLogger.debug('Downloading document from link', {
        'effectiveUrl': effectiveUrl.substring(0, effectiveUrl.length > 100 ? 100 : effectiveUrl.length),
      });
      
      final response = await http.get(Uri.parse(effectiveUrl));
      
      if (response.statusCode != 200) {
        EVLogger.error('Download from link failed, falling back to download-stream', {
          'statusCode': response.statusCode,
        });
        // Fall back to download-stream endpoint
        return await _downloadFromStream(documentId);
      }
      
      return response.bodyBytes;
    } catch (error) {
      EVLogger.error('Failed to download document, trying download-stream as fallback', error);
      // Last resort: try download-stream endpoint
      try {
        return await _downloadFromStream(documentId);
      } catch (fallbackError) {
        EVLogger.error('Download-stream fallback also failed', fallbackError);
        throw Exception('Failed to download document: $error');
      }
    }
  }
  
  Future<Uint8List> _downloadFromStream(String documentId) async {
    try {
      final url = _baseService.buildUrl('files/$documentId/download-stream');
      final headers = {
        ..._baseService.createHeaders(serviceName: _serviceName),
        'Accept': 'application/octet-stream, */*',
      };
      
      EVLogger.debug('Downloading document from stream endpoint', {
        'url': url,
        'documentId': documentId,
      });
      
      final response = await http.get(Uri.parse(url), headers: headers);
      
      if (response.statusCode != 200) {
        EVLogger.error('Download-stream failed', {
          'statusCode': response.statusCode,
        });
        throw Exception('Download-stream failed with status: ${response.statusCode}');
      }
      
      return response.bodyBytes;
    } catch (error) {
      EVLogger.error('Failed to download from stream endpoint', error);
      throw Exception('Failed to download from stream: $error');
    }
  }
}

