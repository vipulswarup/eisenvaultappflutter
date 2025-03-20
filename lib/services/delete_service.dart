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
    try {
      EVLogger.info('Attempting to delete files', {
        'backend': backend,
        'fileIds': fileIds,
      });
      
      if (backend.toLowerCase() == 'angora') {
        final url = _angoraService.buildUrl('files?ids=${fileIds.join(',')}');
        EVLogger.debug('Deleting Angora files', {'url': url});
        
        // Get headers from the base service
        final headers = _angoraService.createHeaders();
        
        // Add additional headers needed for this specific request
        headers['x-portal'] = 'mobile';
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
          final message = data['notifications'] ?? 'Delete operation queued successfully';
          EVLogger.info('Files deleted successfully', {'message': message});
          return message;
        } else {
          EVLogger.error('Failed to delete files', {
            'statusCode': response.statusCode,
            'response': response.body,
          });
          throw Exception('Failed to delete files: ${response.statusCode}');
        }
      } else {
        // For Classic/Alfresco
        List<String> successfulDeletes = [];
        List<String> failedDeletes = [];
        
        for (final fileId in fileIds) {
          final url = _classicService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$fileId');
          EVLogger.debug('Deleting Classic/Alfresco file', {'url': url, 'fileId': fileId});
          
          final headers = _classicService.createHeaders();
          EVLogger.debug('Request headers', {'headers': headers});
          
          try {
            final response = await http.delete(
              Uri.parse(url),
              headers: headers,
            );
            
            EVLogger.debug('Delete response for file $fileId', {
              'statusCode': response.statusCode,
              'body': response.body,
            });
            
            if (response.statusCode >= 200 && response.statusCode < 300) {
              successfulDeletes.add(fileId);
            } else {
              failedDeletes.add(fileId);
              EVLogger.error('Failed to delete file $fileId', {
                'statusCode': response.statusCode,
                'response': response.body,
              });
            }
          } catch (e) {
            failedDeletes.add(fileId);
            EVLogger.error('Error deleting file $fileId', {'error': e.toString()});
          }
        }
        
        if (failedDeletes.isEmpty) {
          EVLogger.info('All files deleted successfully');
          return 'Files deleted successfully';
        } else if (successfulDeletes.isEmpty) {
          EVLogger.error('Failed to delete any files');
          throw Exception('Failed to delete files');
        } else {
          EVLogger.warning('Some files could not be deleted', {
            'successful': successfulDeletes.length,
            'failed': failedDeletes.length
          });
          return 'Some files deleted successfully, but ${failedDeletes.length} failed';
        }
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error deleting files', e, stackTrace);
      throw Exception('Failed to delete files: $e');
    }
  }
  
  Future<String> deleteFolders(List<String> folderIds, String backend) async {
    try {
      EVLogger.info('Attempting to delete folders', {
        'backend': backend,
        'folderIds': folderIds,
      });
      
      if (backend.toLowerCase() == 'angora') {
        final url = _angoraService.buildUrl('folders?ids=${folderIds.join(',')}');
        EVLogger.debug('Deleting Angora folders', {'url': url});
        
        final headers = _angoraService.createHeaders();
        headers['x-portal'] = 'mobile';
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
          EVLogger.info('Folders deleted successfully', {'message': message});
          return message;
        } else {
          EVLogger.error('Failed to delete folders', {
            'statusCode': response.statusCode,
            'response': response.body,
          });
          throw Exception('Failed to delete folders: ${response.statusCode}');
        }
      } else {
        // For Classic/Alfresco, reuse the file deletion logic
        return await deleteFiles(folderIds, backend);
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error deleting folders', e, stackTrace);
      throw Exception('Failed to delete folders: $e');
    }
  }
  
  Future<String> deleteDepartments(List<String> departmentIds, String backend) async {
    try {
      EVLogger.info('Attempting to delete departments', {
        'backend': backend,
        'departmentIds': departmentIds,
      });
      
      if (backend.toLowerCase() == 'angora') {
        final url = _angoraService.buildUrl('departments?ids=${departmentIds.join(',')}');
        EVLogger.debug('Deleting Angora departments', {'url': url});
        
        final headers = _angoraService.createHeaders();
        headers['x-portal'] = 'mobile';
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
          final message = data['notifications'] ?? 'Delete operation queued successfully';
          EVLogger.info('Departments deleted successfully', {'message': message});
          return message;
        } else {
          EVLogger.error('Failed to delete departments', {
            'statusCode': response.statusCode,
            'response': response.body,
          });
          throw Exception('Failed to delete departments: ${response.statusCode}');
        }
      } else {
        // Same as file deletion for Alfresco
        return await deleteFiles(departmentIds, backend);
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error deleting departments', e, stackTrace);
      throw Exception('Failed to delete departments: $e');
    }
  }
  
  Future<String> deleteFileVersion(String fileId, String versionId, String backend) async {
    try {
      EVLogger.info('Attempting to delete file version', {
        'backend': backend,
        'fileId': fileId,
        'versionId': versionId,
      });
      
      if (backend.toLowerCase() == 'angora') {
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
      } else {
        // Alfresco version deletion endpoint
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
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error deleting file version', e, stackTrace);
      throw Exception('Failed to delete file version: $e');
    }
  }
  
  Future<String> deleteTrashItems(List<String> trashIds, String backend) async {
    try {
      EVLogger.info('Attempting to delete trash items', {
        'backend': backend,
        'trashIds': trashIds,
      });
      
      if (backend.toLowerCase() == 'angora') {
        final url = _angoraService.buildUrl('trashes?ids=${trashIds.join(',')}');
        EVLogger.debug('Deleting Angora trash items', {'url': url});
        
        final headers = _angoraService.createHeaders();
        headers['x-portal'] = 'mobile';
        headers['x-customer-hostname'] = _customerHostname;
        headers['x-locale'] = 'en';
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
          EVLogger.info('Trash items deleted successfully', {'message': message});
          return message;
        } else {
          EVLogger.error('Failed to delete trash items', {
            'statusCode': response.statusCode,
            'response': response.body,
          });
          throw Exception('Failed to delete trash items: ${response.statusCode}');
        }
      } else {
        // Alfresco trash deletion endpoint
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
      }
    } catch (e, stackTrace) {
      EVLogger.error('Error deleting trash items', e, stackTrace);
      throw Exception('Failed to delete trash items: $e');
    }
  }
}
