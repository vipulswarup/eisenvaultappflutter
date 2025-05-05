import '../../utils/logger.dart';
import 'delete_provider_factory.dart';
import 'delete_provider_interface.dart';

/// Service for deleting repository items
/// 
/// This service provides a unified interface for deleting various types of items
/// (files, folders, departments, etc.) across different repository types.
class DeleteService {
  final DeleteProvider _provider;
  
  /// Create a DeleteService using the specified repository details
  /// 
  /// This constructor creates the appropriate DeleteProvider under the hood.
  /// 
  /// [repositoryType]: 'Angora' or 'Classic'
  /// [baseUrl]: The base URL for the repository
  /// [authToken]: Authentication token
  /// [customerHostname]: Required for Angora repositories
  DeleteService({
    required String repositoryType,
    required String baseUrl,
    required String authToken,
    required String customerHostname,
  }) : _provider = DeleteProviderFactory.getProvider(
         repositoryType: repositoryType,
         baseUrl: baseUrl,
         authToken: authToken,
         customerHostname: customerHostname,
       );
  
  /// Create a DeleteService with an existing provider
  /// 
  /// This constructor is useful for testing or when you need more control
  /// over the provider instance.
  DeleteService.withProvider(this._provider);
  
  /// Delete one or more files from the repository
  Future<String> deleteFiles(List<String> fileIds) async {
    try {
      
      return await _provider.deleteFiles(fileIds);
    } catch (e) {
      EVLogger.error('Error in DeleteService.deleteFiles', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Delete one or more folders from the repository
  Future<String> deleteFolders(List<String> folderIds) async {
    try {
      
      return await _provider.deleteFolders(folderIds);
    } catch (e) {
      EVLogger.error('Error in DeleteService.deleteFolders', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Delete one or more departments from the repository
  Future<String> deleteDepartments(List<String> departmentIds) async {
    try {
      
      return await _provider.deleteDepartments(departmentIds);
    } catch (e) {
      EVLogger.error('Error in DeleteService.deleteDepartments', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Delete a specific version of a file
  Future<String> deleteFileVersion(String fileId, String versionId) async {
    try {
      
      return await _provider.deleteFileVersion(fileId, versionId);
    } catch (e) {
      EVLogger.error('Error in DeleteService.deleteFileVersion', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Delete one or more items from the trash
  Future<String> deleteTrashItems(List<String> trashIds) async {
    try {
      
      return await _provider.deleteTrashItems(trashIds);
    } catch (e) {
      EVLogger.error('Error in DeleteService.deleteTrashItems', {'error': e.toString()});
      rethrow;
    }
  }
}
