import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/browse_item.dart';
import '../../utils/logger.dart';
import '../api/angora_base_service.dart';
import '../api/classic_base_service.dart';

/// Service for renaming repository items.
///
/// Provides a unified interface for renaming files, folders, and departments
/// across Angora and Classic repository types.
class RenameService {
  final String _repositoryType;
  final String _customerHostname;

  // Base services created once and reused across all rename calls
  final AngoraBaseService? _angoraService;
  final ClassicBaseService? _classicService;

  RenameService({
    required String repositoryType,
    required String baseUrl,
    required String authToken,
    required String customerHostname,
  })  : _repositoryType = repositoryType,
        _customerHostname = customerHostname,
        _angoraService = repositoryType.toLowerCase() == 'angora'
            ? (AngoraBaseService(baseUrl)..setToken(authToken))
            : null,
        _classicService = repositoryType.toLowerCase() != 'angora'
            ? (ClassicBaseService(baseUrl)..setToken(authToken))
            : null;

  /// Rename an item based on its type.
  Future<String> renameItem(BrowseItem item, String newName) async {
    try {
      if (item.isDepartment) {
        return await _rename(item.id, newName, entityType: 'departments', entityLabel: 'Department');
      } else if (item.type == 'folder') {
        return await _rename(item.id, newName, entityType: 'folders', entityLabel: 'Folder');
      } else {
        return await _rename(item.id, newName, entityType: 'files', entityLabel: 'File');
      }
    } catch (e) {
      EVLogger.error('Error in RenameService.renameItem', {'error': e.toString()});
      rethrow;
    }
  }

  Future<String> renameFile(String fileId, String newName) =>
      _rename(fileId, newName, entityType: 'files', entityLabel: 'File');

  Future<String> renameFolder(String folderId, String newName) =>
      _rename(folderId, newName, entityType: 'folders', entityLabel: 'Folder');

  Future<String> renameDepartment(String departmentId, String newName) =>
      _rename(departmentId, newName, entityType: 'departments', entityLabel: 'Department');

  /// Single consolidated rename method for both backends.
  Future<String> _rename(
    String itemId,
    String newName, {
    required String entityType,
    required String entityLabel,
  }) async {
    if (_repositoryType.toLowerCase() == 'angora') {
      return _renameAngora(itemId, newName, entityType: entityType, entityLabel: entityLabel);
    } else {
      return _renameClassic(itemId, newName, entityLabel: entityLabel);
    }
  }

  Future<String> _renameAngora(
    String itemId,
    String newName, {
    required String entityType,
    required String entityLabel,
  }) async {
    final url = _angoraService!.buildUrl('$entityType/$itemId');
    final headers = _angoraService!.createHeaders();
    headers['x-portal'] = 'mobile';
    headers['x-customer-hostname'] = _customerHostname;

    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'name': newName}),
    );

    if (response.statusCode == 200) {
      return '$entityLabel renamed successfully';
    } else {
      throw Exception('Failed to rename $entityLabel: ${response.statusCode}');
    }
  }

  Future<String> _renameClassic(
    String itemId,
    String newName, {
    required String entityLabel,
  }) async {
    final url = _classicService!.buildUrl(
      'api/-default-/public/alfresco/versions/1/nodes/$itemId',
    );
    final headers = _classicService!.createHeaders();

    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'name': newName}),
    );

    if (response.statusCode == 200) {
      return '$entityLabel renamed successfully';
    } else {
      throw Exception('Failed to rename $entityLabel: ${response.statusCode}');
    }
  }
}
