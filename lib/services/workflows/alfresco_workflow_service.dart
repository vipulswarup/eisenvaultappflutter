import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/workflow_task.dart';
import '../../utils/http_utils.dart';

abstract class WorkflowService {
  Future<List<WorkflowTask>> getMyTasks();
  Future<WorkflowTask?> getTask(String id);
  Future<List<String>> getDocumentNames(WorkflowTask task);
}

/// Read-only, account-scoped access to Alfresco Content Services workflows.
class AlfrescoWorkflowService implements WorkflowService {
  final String baseUrl, authToken;
  final http.Client? client;
  AlfrescoWorkflowService({
    required this.baseUrl,
    required this.authToken,
    this.client,
  });

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/$path',
  ).replace(queryParameters: query);

  Future<Map<String, dynamic>?> _get(
    Uri uri, {
    bool missingAllowed = false,
  }) async {
    final headers = {'Authorization': authToken, 'Accept': 'application/json'};
    final response =
        client == null
            ? await getWithTimeout(uri, headers: headers)
            : await client!
                .get(uri, headers: headers)
                .timeout(apiRequestTimeout);
    if (missingAllowed && response.statusCode == 404) return null;
    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please sign in again.');
    }
    if (response.statusCode == 403) {
      throw Exception('You do not have permission to view these tasks.');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load workflows (HTTP ${response.statusCode}).',
      );
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid workflow response');
    }
    return json;
  }

  @override
  Future<List<WorkflowTask>> getMyTasks() async {
    final tasks = <String, WorkflowTask>{};
    var skip = 0;
    while (true) {
      final json =
          (await _get(
            _uri('s/api/task-instances', {
              'state': 'IN_PROGRESS',
              'pooledTasks': 'true',
              'maxItems': '100',
              'skipCount': '$skip',
            }),
          ))!;
      final rows = json['data'];
      if (rows is! List) throw const FormatException('Invalid task list');
      for (final row in rows) {
        final task = WorkflowTask.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        if (task.isActive) tasks[task.id] = task;
      }
      skip += rows.length;
      final total = (json['paging'] as Map?)?['totalItems'] as num?;
      if (rows.isEmpty || (total != null ? skip >= total : rows.length < 100)) {
        break;
      }
    }
    return tasks.values.toList()..sort(WorkflowTask.compare);
  }

  @override
  Future<WorkflowTask?> getTask(String id) async {
    final json = await _get(
      _uri('s/api/task-instances/${Uri.encodeComponent(id)}'),
      missingAllowed: true,
    );
    if (json == null) return null;
    final task = WorkflowTask.fromJson(
      Map<String, dynamic>.from(json['data'] as Map),
    );
    // A readable task may have been reassigned since the list was loaded.
    if (task.isActive &&
        !(await getMyTasks()).any((current) => current.id == id)) {
      return null;
    }
    return task;
  }

  @override
  Future<List<String>> getDocumentNames(WorkflowTask task) async {
    final package = task.packageNode;
    if (package == null || package.isEmpty) return [];
    final nodeId = package.split('/').last;
    final names = <String>[];
    var skip = 0;
    while (true) {
      final json =
          (await _get(
            _uri(
              'api/-default-/public/alfresco/versions/1/nodes/${Uri.encodeComponent(nodeId)}/children',
              {'maxItems': '100', 'skipCount': '$skip'},
            ),
          ))!;
      final list = json['list'] as Map;
      final entries = list['entries'] as List;
      for (final row in entries) {
        final entry = (row as Map)['entry'] as Map;
        if (entry['isFile'] == true && entry['name'] is String) {
          names.add(entry['name'] as String);
        }
      }
      if ((list['pagination'] as Map?)?['hasMoreItems'] != true) break;
      if (entries.isEmpty) {
        throw const FormatException('Invalid document pagination');
      }
      skip += entries.length;
    }
    return names;
  }
}
