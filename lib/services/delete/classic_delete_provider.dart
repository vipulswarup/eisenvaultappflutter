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
      
      
      final headers = _classicService.createHeaders();
      
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      
      if (response.statusCode == 204) {
        
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
     
      
      final headers = _classicService.createHeaders();
     
      
      final body = json.encode({
        'nodeIds': trashIds,
      });
     
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 204) {
        
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
      
      
      List<String> successfulDeletes = [];
      List<String> failedDeletes = [];
      
      for (final id in ids) {
        final url = _classicService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$id');
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
