// Simple service to delete files, folders, departments, versions, and trash items
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/logger.dart';
import '../services/api/classic_base_service.dart';
import '../services/api/angora_base_service.dart';

class DeleteService {
  final AngoraBaseService _angoraService;
  final ClassicBaseService _classicService;
  final String _customerHostname;
  
  DeleteService({
    required String authToken,
    required String baseUrl,
    required String customerHostname,
  }) : _angoraService = AngoraBaseService(baseUrl),
       _classicService = ClassicBaseService(baseUrl),
       _customerHostname = customerHostname {
    // Initialize services with auth token
    _angoraService.setToken('Bearer $authToken');
    _classicService.setToken( authToken );
  }
  
  Future<String> deleteFiles(List<String> fileIds, String backend) async {
    return _performDelete(
      backend: backend,
      entityType: 'files',
      ids: fileIds
    );
  }

  Future<String> deleteFolders(List<String> folderIds, String backend) async {
    return _performDelete(
      backend: backend,
      entityType: 'folders',
      ids: folderIds
    );
  }

  Future<String> deleteDepartments(List<String> departmentIds, String backend) async {
    return _performDelete(
      backend: backend,
      entityType: 'departments',
      ids: departmentIds
    );
  }

  Future<String> deleteTrashItems(List<String> trashIds, String backend) async {
    return _performDelete(
      backend: backend,
      entityType: 'trashes',
      ids: trashIds,
      additionalHeaders: {'x-locale': 'en'}
    );
  }
  
  /// Generic delete method to reduce duplication
  Future<String> _performDelete({
    required String backend,
    required String entityType, // 'files', 'folders', 'departments', 'trashes'
    required List<String> ids,
    Map<String, String>? additionalHeaders,
  }) async {
    try {
      EVLogger.info('Attempting to delete $entityType', {
        'backend': backend,
        'ids': ids,
      });
      
      if (backend.toLowerCase() == 'angora') {
        // Angora implementation
        final url = _angoraService.buildUrl('$entityType?ids=${ids.join(',')}');
        
        
        final headers = _angoraService.createHeaders();
        headers['x-portal'] = 'mobile';
        headers['x-customer-hostname'] = _customerHostname;
        
        // Add any additional headers
        if (additionalHeaders != null) {
          headers.addAll(additionalHeaders);
        }
        
        
        
        final response = await http.delete(
          Uri.parse(url),
          headers: headers,
        );
        
        
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
      } else {
        // Classic/Alfresco implementation
        List<String> successfulDeletes = [];
        List<String> failedDeletes = [];
        
        for (final id in ids) {
          final url = _classicService.buildUrl(_getClassicEndpoint(entityType, id));
        
          
          final headers = _classicService.createHeaders();
        
          
          try {
            final response = await http.delete(
              Uri.parse(url),
              headers: headers,
            );
            
            
            if (response.statusCode >= 200 && response.statusCode < 300) {
              successfulDeletes.add(id);
            } else {
              failedDeletes.add(id);
              EVLogger.error('Failed to delete $entityType $id', {
                'statusCode': response.statusCode,
                'response': response.body,
              });
            }
          } catch (e) {
            failedDeletes.add(id);
            EVLogger.error('Error deleting $entityType $id', {'error': e.toString()});
          }
        }
        
        return _formatDeleteResult(entityType, successfulDeletes, failedDeletes);
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error deleting $entityType', e, stackTrace);
      throw Exception('Failed to delete $entityType: $e');
    }
  }

  // Helper for Classic/Alfresco endpoint determination
  String _getClassicEndpoint(String entityType, String id) {
    switch (entityType) {
      case 'files':
      case 'folders':
      case 'departments':
        return 'api/-default-/public/alfresco/versions/1/nodes/$id';
      case 'trashes':
        return 'api/-default-/public/alfresco/versions/1/deleted-nodes';
      default:
        return 'api/-default-/public/alfresco/versions/1/nodes/$id';
    }
  }

  // Helper to format delete result message
  String _formatDeleteResult(String entityType, List<String> successfulDeletes, List<String> failedDeletes) {
    if (failedDeletes.isEmpty) {
      EVLogger.info('All $entityType deleted successfully');
      return '$entityType deleted successfully';
    } else if (successfulDeletes.isEmpty) {
      EVLogger.error('Failed to delete any $entityType');
      throw Exception('Failed to delete $entityType');
    } else {
      EVLogger.warning('Some $entityType could not be deleted', {
        'successful': successfulDeletes.length,
        'failed': failedDeletes.length
      });
      return 'Some $entityType deleted successfully, but ${failedDeletes.length} failed';
    }
  }
}
