import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/classic_base_service.dart';
import '../../utils/logger.dart';
import 'delete_provider_interface.dart';

class ClassicDeleteProvider implements DeleteProvider {
  final ClassicBaseService _classicService;
  
  ClassicDeleteProvider({
    required ClassicBaseService classicService,
  }) : _classicService = classicService;
  
  @override
  Future<String> deleteFiles(List<String> fileIds) async {
    return _performBatchDelete(
      entityType: 'files',
      ids: fileIds,
    );
  }
  
  @override
  Future<String> deleteFolders(List<String> folderIds) async {
    return _performBatchDelete(
      entityType: 'folders',
      ids: folderIds,
    );
  }
  
  @override
  Future<String> deleteDepartments(List<String> departmentIds) async {
    return _performBatchDelete(
      entityType: 'departments',
      ids: departmentIds,
    );
  }
  
  @override
  Future<String> deleteFileVersion(String fileId, String versionId) async {
    try {
      final url = _classicService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$fileId/versions/$versionId');
      EVLogger.debug('Deleting Classic/Alfresco file version', {'url': url});
      
      final headers = _classicService.createHeaders();
      EVLogger.debug('Request headers', {'headers': headers});
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      EVLogger.debug('Delete response', {
        'statusCode': response.statusCode,
        'body': response.body,
      });
      
      if (response.statusCode == 204) {
        EVLogger.info('File version deleted successfully');
        return 'Version deleted successfully';
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
    try {
      final url = _classicService.buildUrl('api/-default-/public/alfresco/versions/1/deleted-nodes');
      EVLogger.debug('Deleting Classic/Alfresco trash items', {'url': url});
      
      final headers = _classicService.createHeaders();
      EVLogger.debug('Request headers', {'headers': headers});
      
      final body = json.encode({
        'nodeIds': trashIds,
      });
      EVLogger.debug('Request body', {'body': body});
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      
      EVLogger.debug('Delete response', {
        'statusCode': response.statusCode,
        'body': response.body,
      });
      
      if (response.statusCode == 204) {
        EVLogger.info('Trash items deleted successfully');
        return 'Trash items deleted successfully';
      } else {
        EVLogger.error('Failed to delete trash items', {
          'statusCode': response.statusCode,
          'response': response.body,
        });
        throw Exception('Failed to delete trash items: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error deleting trash items', e, stackTrace);
      throw Exception('Failed to delete trash items: $e');
    }
  }
  
  /// Generic delete method for batch operations
  Future<String> _performBatchDelete({
    required String entityType,
    required List<String> ids,
  }) async {
    try {
      EVLogger.info('Attempting to delete $entityType', {
        'ids': ids,
      });
      
      List<String> successfulDeletes = [];
      List<String> failedDeletes = [];
      
      for (final id in ids) {
        final url = _classicService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$id');
        EVLogger.debug('Deleting $entityType', {'url': url, 'id': id});
        
        final headers = _classicService.createHeaders();
        EVLogger.debug('Request headers', {'headers': headers});
        
        try {
          final response = await http.delete(
            Uri.parse(url),
            headers: headers,
          );
          
          EVLogger.debug('Delete response for $id', {
            'statusCode': response.statusCode,
            'body': response.body,
          });
          
          if (response.statusCode >= 200 && response.statusCode < 300) {
            successfulDeletes.add(id);
          } else {
            failedDeletes.add(id);
            EVLogger.error('Failed to delete $id', {
              'statusCode': response.statusCode,
              'response': response.body,
            });
          }
        } catch (e) {
          failedDeletes.add(id);
          EVLogger.error('Error deleting $id', {'error': e.toString()});
        }
      }
      
      return _formatDeleteResult(entityType, successfulDeletes, failedDeletes);
    } catch (e, stackTrace) {
      EVLogger.error('Error in batch delete operation', e, stackTrace);
      throw Exception('Failed to delete $entityType: $e');
    }
  }
  
  /// Helper to format delete result message
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
