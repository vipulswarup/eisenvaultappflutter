import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/browse_item.dart';
import '../../utils/logger.dart';
import '../api/angora_base_service.dart';
import '../api/classic_base_service.dart';

/// Service for renaming repository items
/// 
/// This service provides a unified interface for renaming various types of items
/// (files, folders, departments, etc.) across different repository types.
class RenameService {
  final String _repositoryType;
  final String _baseUrl;
  final String _authToken;
  final String _customerHostname;
  
  /// Create a RenameService using the specified repository details
  /// 
  /// [repositoryType]: 'Angora' or 'Classic'
  /// [baseUrl]: The base URL for the repository
  /// [authToken]: Authentication token
  /// [customerHostname]: Required for Angora repositories
  RenameService({
    required String repositoryType,
    required String baseUrl,
    required String authToken,
    required String customerHostname,
  }) : _repositoryType = repositoryType,
       _baseUrl = baseUrl,
       _authToken = authToken,
       _customerHostname = customerHostname;
  
  /// Rename a file in the repository
  Future<String> renameFile(String fileId, String newName) async {
    try {
      if (_repositoryType.toLowerCase() == 'angora') {
        return await _renameAngoraFile(fileId, newName);
      } else {
        return await _renameClassicFile(fileId, newName);
      }
    } catch (e) {
      EVLogger.error('Error in RenameService.renameFile', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Rename a folder in the repository
  Future<String> renameFolder(String folderId, String newName) async {
    try {
      if (_repositoryType.toLowerCase() == 'angora') {
        return await _renameAngoraFolder(folderId, newName);
      } else {
        return await _renameClassicFolder(folderId, newName);
      }
    } catch (e) {
      EVLogger.error('Error in RenameService.renameFolder', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Rename a department in the repository
  Future<String> renameDepartment(String departmentId, String newName) async {
    try {
      if (_repositoryType.toLowerCase() == 'angora') {
        return await _renameAngoraDepartment(departmentId, newName);
      } else {
        return await _renameClassicDepartment(departmentId, newName);
      }
    } catch (e) {
      EVLogger.error('Error in RenameService.renameDepartment', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Rename an item based on its type
  Future<String> renameItem(BrowseItem item, String newName) async {
    try {
      if (item.isDepartment) {
        return await renameDepartment(item.id, newName);
      } else if (item.type == 'folder') {
        return await renameFolder(item.id, newName);
      } else {
        return await renameFile(item.id, newName);
      }
    } catch (e) {
      EVLogger.error('Error in RenameService.renameItem', {'error': e.toString()});
      rethrow;
    }
  }
  
  /// Angora implementation for renaming files
  Future<String> _renameAngoraFile(String fileId, String newName) async {
    final angoraService = AngoraBaseService(_baseUrl);
    angoraService.setToken(_authToken);
    
    final url = angoraService.buildUrl('files/$fileId');
    final headers = angoraService.createHeaders();
    headers['x-portal'] = 'mobile';
    headers['x-customer-hostname'] = _customerHostname;
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'name': newName,
      }),
    );
    
    if (response.statusCode == 200) {
      return 'File renamed successfully';
    } else {
      throw Exception('Failed to rename file: ${response.statusCode}');
    }
  }
  
  /// Angora implementation for renaming folders
  Future<String> _renameAngoraFolder(String folderId, String newName) async {
    final angoraService = AngoraBaseService(_baseUrl);
    angoraService.setToken(_authToken);
    
    final url = angoraService.buildUrl('folders/$folderId');
    final headers = angoraService.createHeaders();
    headers['x-portal'] = 'mobile';
    headers['x-customer-hostname'] = _customerHostname;
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'name': newName,
      }),
    );
    
    if (response.statusCode == 200) {
      return 'Folder renamed successfully';
    } else {
      throw Exception('Failed to rename folder: ${response.statusCode}');
    }
  }
  
  /// Angora implementation for renaming departments
  Future<String> _renameAngoraDepartment(String departmentId, String newName) async {
    final angoraService = AngoraBaseService(_baseUrl);
    angoraService.setToken(_authToken);
    
    final url = angoraService.buildUrl('departments/$departmentId');
    final headers = angoraService.createHeaders();
    headers['x-portal'] = 'mobile';
    headers['x-customer-hostname'] = _customerHostname;
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'name': newName,
      }),
    );
    
    if (response.statusCode == 200) {
      return 'Department renamed successfully';
    } else {
      throw Exception('Failed to rename department: ${response.statusCode}');
    }
  }
  
  /// Classic implementation for renaming files
  Future<String> _renameClassicFile(String fileId, String newName) async {
    final classicService = ClassicBaseService(_baseUrl);
    classicService.setToken(_authToken);
    
    final url = classicService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$fileId');
    final headers = classicService.createHeaders();
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'name': newName,
      }),
    );
    
    if (response.statusCode == 200) {
      return 'File renamed successfully';
    } else {
      throw Exception('Failed to rename file: ${response.statusCode}');
    }
  }
  
  /// Classic implementation for renaming folders
  Future<String> _renameClassicFolder(String folderId, String newName) async {
    final classicService = ClassicBaseService(_baseUrl);
    classicService.setToken(_authToken);
    
    final url = classicService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$folderId');
    final headers = classicService.createHeaders();
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'name': newName,
      }),
    );
    
    if (response.statusCode == 200) {
      return 'Folder renamed successfully';
    } else {
      throw Exception('Failed to rename folder: ${response.statusCode}');
    }
  }
  
  /// Classic implementation for renaming departments
  Future<String> _renameClassicDepartment(String departmentId, String newName) async {
    final classicService = ClassicBaseService(_baseUrl);
    classicService.setToken(_authToken);
    
    final url = classicService.buildUrl('api/-default-/public/alfresco/versions/1/nodes/$departmentId');
    final headers = classicService.createHeaders();
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'name': newName,
      }),
    );
    
    if (response.statusCode == 200) {
      return 'Department renamed successfully';
    } else {
      throw Exception('Failed to rename department: ${response.statusCode}');
    }
  }
} 