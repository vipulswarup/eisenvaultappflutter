import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/workflow_task.dart';
import '../../models/workflow_task_form.dart';
import '../../utils/http_utils.dart';

abstract class WorkflowService {
  Future<List<WorkflowTask>> getMyTasks();
  Future<WorkflowTask?> getTask(String id);
  Future<List<String>> getDocumentNames(WorkflowTask task);
}

abstract class WorkflowActionService {
  Future<WorkflowTaskForm> getTaskForm(String id);
  Future<void> completeTask(
    WorkflowTaskForm form,
    Map<String, String> values,
    String transition,
  );
}

class WorkflowTaskChanged implements Exception {
  @override
  String toString() =>
      'This task changed or is no longer assigned to you. The form has been refreshed.';
}

/// Account-scoped access to Alfresco Content Services workflows.
class AlfrescoWorkflowService
    implements WorkflowService, WorkflowActionService {
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
    for (final pooled in [false, true]) {
      var skip = 0;
      while (true) {
        final json =
            (await _get(
              _uri('s/api/task-instances', {
                'state': 'IN_PROGRESS',
                'pooledTasks': '$pooled',
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
          if (task.isActive &&
              (row['workflowInstance'] as Map?)?['name'] !=
                  'activiti\$activitiPermissionProcess') {
            tasks[task.id] = task;
          }
        }
        skip += rows.length;
        final total = (json['paging'] as Map?)?['totalItems'] as num?;
        if (rows.isEmpty ||
            (total != null ? skip >= total : rows.length < 100)) {
          break;
        }
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

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = {
      'Authorization': authToken,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    // Never retry a mutation: an uncertain response might already have completed the task.
    final response = await (client ?? appHttpClient)
        .post(_uri(path), headers: headers, body: jsonEncode(body))
        .timeout(apiRequestTimeout);
    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please sign in again.');
    }
    if (response.statusCode == 403 ||
        response.statusCode == 404 ||
        response.statusCode == 409) {
      throw WorkflowTaskChanged();
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'The server could not process the task form (HTTP ${response.statusCode}). Refresh before trying again.',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  @override
  Future<WorkflowTaskForm> getTaskForm(String id) async {
    final task = await _get(
      _uri('s/api/task-instances/${Uri.encodeComponent(id)}'),
      missingAllowed: true,
    );
    if (task == null || !(await getMyTasks()).any((t) => t.id == id)) {
      throw WorkflowTaskChanged();
    }
    final taskData = Map<String, dynamic>.from(task['data'] as Map);
    if (!WorkflowTaskForm.supportsTask(taskData)) {
      return WorkflowTaskForm.fromJson(id, taskData, {
        'definition': {'fields': []},
        'formData': {},
      });
    }
    final form = await _post('s/api/formdefinitions', {
      'itemKind': 'task',
      'itemId': id,
    });
    return WorkflowTaskForm.fromJson(
      id,
      Map<String, dynamic>.from(task['data'] as Map),
      Map<String, dynamic>.from(form['data'] as Map),
    );
  }

  @override
  Future<void> completeTask(
    WorkflowTaskForm form,
    Map<String, String> values,
    String transition,
  ) async {
    final fresh = await getTaskForm(form.taskId);
    if (fresh.fingerprint != form.fingerprint) throw WorkflowTaskChanged();
    final body = fresh.submission(values, transition);
    await _post(
      's/api/task/${Uri.encodeComponent(form.taskId)}/formprocessor',
      body,
    );
    final response = await _get(
      _uri('s/api/task-instances/${Uri.encodeComponent(form.taskId)}'),
      missingAllowed: true,
    );
    final completed = response?['data'] as Map?;
    final state = completed?['state']?.toString().toUpperCase();
    if (!['COMPLETED', 'COMPLETE'].contains(state)) {
      throw Exception(
        'Unable to confirm task completion. Refresh before trying again.',
      );
    }
    final action = fresh.actions.singleWhere((a) => a.id == transition);
    for (final property in action.properties.entries) {
      final key = property.key.replaceFirst('prop_', '');
      if ((completed?['properties'] as Map?)?[key] != property.value) {
        throw Exception(
          'Unable to confirm the selected review outcome. Refresh the task before continuing.',
        );
      }
    }
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
