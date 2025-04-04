import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/angora_base_service.dart';
import '../../utils/logger.dart';
import 'delete_provider_interface.dart';

class AngoraDeleteProvider implements DeleteProvider {
  final AngoraBaseService _angoraService;
  final String _customerHostname;
  
  AngoraDeleteProvider({
    required AngoraBaseService angoraService,
    required String customerHostname,
  }) : _angoraService = angoraService,
       _customerHostname = customerHostname;
  
  @override
  Future<String> deleteFiles(List<String> fileIds) async {
    return _performDelete(
      entityType: 'files',
      ids: fileIds,
      additionalHeaders: {
        'x-portal': 'mobile',
        'x-customer-hostname': _customerHostname,
      },
    );
  }
  
  @override
  Future<String> deleteFolders(List<String> folderIds) async {
    return _performDelete(
      entityType: 'folders',
      ids: folderIds,
      additionalHeaders: {
        'x-portal': 'mobile',
      },
    );
  }
  
  @override
  Future<String> deleteDepartments(List<String> departmentIds) async {
    return _performDelete(
      entityType: 'departments',
      ids: departmentIds,
      additionalHeaders: {
        'x-portal': 'mobile',
        'x-customer-hostname': _customerHostname,
      },
    );
  }
  
  @override
  Future<String> deleteFileVersion(String fileId, String versionId) async {
    try {
      final url = _angoraService.buildUrl('files/$fileId/versions/$versionId');
      
      final headers = _angoraService.createHeaders(serviceName: 'service-file');
      headers['x-portal'] = 'mobile';  // Set to mobile instead of web
      headers['x-customer-hostname'] = _customerHostname;
      
      // Log headers for debugging
      EVLogger.info('Delete version request headers', {
        'headers': headers.toString()
      });
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final message = data['notifications'] ?? 'Version deleted successfully';
        EVLogger.info('File version deleted successfully', {'message': message});
        return message;
      } else {
        EVLogger.error('Failed to delete version', {
          'statusCode': response.statusCode,
          'response': response.body,
        });
        throw Exception('Failed to delete version: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error deleting file version', e, stackTrace);
      throw Exception('Failed to delete file version: $e');
    }
  }
  
  @override
  Future<String> deleteTrashItems(List<String> trashIds) async {
    return _performDelete(
      entityType: 'trashes',
      ids: trashIds,
      additionalHeaders: {
        'x-portal': 'mobile',
        'x-customer-hostname': _customerHostname,
        'x-locale': 'en',
      },
    );
  }
  
  /// Generic delete method to reduce duplication
  Future<String> _performDelete({
    required String entityType,
    required List<String> ids,
    Map<String, String>? additionalHeaders,
  }) async {
    try {
      EVLogger.info('Attempting to delete $entityType', {
        'ids': ids,
      });
      
      final url = _angoraService.buildUrl('$entityType?ids=${ids.join(',')}');
      
      // Get headers with service-file parameter
      final headers = _angoraService.createHeaders(serviceName: 'service-file');
      
      // Ensure mobile portal is set for the right API endpoint context
      headers['x-portal'] = 'mobile';  // Instead of default 'web'
      headers['x-customer-hostname'] = _customerHostname;
      
      // Add any additional headers
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }
      
      // Log the headers for debugging (remove sensitive data in production)
      EVLogger.info('Delete request headers', {
        'headers': headers.toString()
      });
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle the case where notifications might be a list
        String message;
        if (data['notifications'] != null) {
          if (data['notifications'] is List) {
            // Join list items into a single string
            message = (data['notifications'] as List).join('. ');
          } else {
            // Use as is if it's already a string
            message = data['notifications'].toString();
          }
        } else {
          message = 'Delete operation queued successfully';
        }
        
        EVLogger.info('$entityType deleted successfully', {'message': message});
        return message;
      } else {
        EVLogger.error('Failed to delete $entityType', {
          'statusCode': response.statusCode,
          'response': response.body,
        });
        throw Exception('Failed to delete $entityType: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error deleting $entityType', e, stackTrace);
      throw Exception('Failed to delete $entityType: $e');
    }
  }
}
