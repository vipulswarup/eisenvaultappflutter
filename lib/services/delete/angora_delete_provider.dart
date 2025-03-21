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
      EVLogger.debug('Deleting Angora file version', {'url': url});
      
      final headers = _angoraService.createHeaders();
      headers['x-customer-hostname'] = _customerHostname;
      EVLogger.debug('Request headers', {'headers': headers});
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      EVLogger.debug('Delete response', {
        'statusCode': response.statusCode,
        'body': response.body,
      });
      
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
      EVLogger.debug('Deleting Angora $entityType', {'url': url});
      
      final headers = _angoraService.createHeaders();
      
      // Add any additional headers
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }
      
      EVLogger.debug('Request headers', {'headers': headers});
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      EVLogger.debug('Delete response', {
        'statusCode': response.statusCode,
        'body': response.body,
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final message = data['notifications'] ?? 'Delete operation queued successfully';
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
