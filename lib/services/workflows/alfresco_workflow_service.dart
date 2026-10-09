import 'dart:convert';
import '../../models/browse_item.dart';
import 'package:http/http.dart' as http;
import '../../models/workflow_task.dart';
import '../../models/workflow_task_form.dart';
import '../../models/workflow_start_form.dart';
import '../../utils/http_utils.dart';

abstract class WorkflowService {
  Future<List<WorkflowTask>> getMyTasks();
  Future<WorkflowTask?> getTask(String id);
  Future<List<String>> getDocumentNames(WorkflowTask task);
}

abstract class WorkflowDocumentService {
  String get baseUrl;
  String get authToken;
  Future<List<BrowseItem>> getDocuments(WorkflowTask task);
}

abstract class WorkflowActionService {
  Future<WorkflowTaskForm> getTaskForm(String id);
  Future<void> completeTask(
    WorkflowTaskForm form,
    Map<String, String> values,
    String transition,
  );
}

abstract class WorkflowOwnershipService {
  Future<void> changeOwnership(WorkflowTask snapshot, {required bool claim});
}

abstract class WorkflowStartService {
  Future<List<WorkflowDefinition>> getStartDefinitions();
  Future<WorkflowStartForm> getStartForm(
    WorkflowDefinition definition,
    String nodeId,
  );
  Future<List<WorkflowAssignee>> searchAssignees(String nodeId, String query);
  Future<String> startWorkflow(
    WorkflowStartForm form,
    Map<String, String> values,
    WorkflowAssignee assignee,
  );
}

class WorkflowTaskChanged implements Exception {
  @override
  String toString() =>
      'This task changed or is no longer assigned to you. The form has been refreshed.';
}

/// Account-scoped access to Alfresco Content Services workflows.
class AlfrescoWorkflowService
    implements
        WorkflowService,
        WorkflowDocumentService,
        WorkflowActionService,
        WorkflowOwnershipService,
        WorkflowStartService {
  @override
  final String baseUrl;
  @override
  final String authToken;
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
    bool permissionDeniedAllowed = false,
  }) async {
    final headers = {'Authorization': authToken, 'Accept': 'application/json'};
    final response =
        client == null
            ? await getWithTimeout(uri, headers: headers)
            : await client!
                .get(uri, headers: headers)
                .timeout(apiRequestTimeout);
    if (missingAllowed && response.statusCode == 404) return null;
    if (permissionDeniedAllowed && response.statusCode == 403) return null;
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
  Future<List<WorkflowDefinition>> getStartDefinitions() async {
    final response = (await _get(_uri('s/api/workflow-definitions')))!;
    return (response['data'] as List)
        .map((row) => WorkflowDefinition.fromJson(row as Map))
        .where((d) => d.name != 'activiti\$activitiPermissionProcess')
        .toList();
  }

  Future<Map<String, dynamic>> _startDocument(String nodeId) async {
    final response = await _get(
      _uri(
        'api/-default-/public/alfresco/versions/1/nodes/${Uri.encodeComponent(nodeId)}',
        {'include': 'permissions'},
      ),
    );
    final node = Map<String, dynamic>.from(response!['entry'] as Map);
    if (node['isFile'] != true) {
      throw const WorkflowStartNotSubmitted(
        'Select a document to start a workflow.',
      );
    }
    return node;
  }

  @override
  Future<WorkflowStartForm> getStartForm(
    WorkflowDefinition definition,
    String nodeId,
  ) async {
    final node = await _startDocument(nodeId);
    if (!definition.supported) {
      return WorkflowStartForm.fromJson(definition, node, {});
    }
    final response = await _post('s/api/formdefinitions', {
      'itemKind': 'workflow',
      'itemId': definition.name,
    });
    return WorkflowStartForm.fromJson(
      definition,
      node,
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<bool> _assigneeCanRead(
    Map<String, dynamic> node,
    Map person,
    String currentUsername,
  ) async {
    final username = person['userName'] as String;
    if (person['enabled'] != true) return false;
    // Check content access for self; readable metadata alone is insufficient.
    if (username == currentUsername) {
      final request = http.Request(
        'GET',
        _uri(
          'api/-default-/public/alfresco/versions/1/nodes/${Uri.encodeComponent(node['id'] as String)}/content',
        ),
      );
      request.headers.addAll({
        'Authorization': authToken,
        'Range': 'bytes=0-0',
      });
      final response = await (client ?? appHttpClient)
          .send(request)
          .timeout(apiRequestTimeout);
      // Do not download the document if a server ignores the Range header.
      await response.stream.listen((_) {}).cancel();
      return response.statusCode == 200 || response.statusCode == 206;
    }
    if (person['isAdminAuthority'] == true) return true;
    if (node['permissions'] is! Map) return false;
    final authorities = <String>{username, 'GROUP_EVERYONE'};
    var skip = 0;
    while (true) {
      final response = await _get(
        _uri(
          'api/-default-/public/alfresco/versions/1/people/${Uri.encodeComponent(username)}/groups',
          {'skipCount': '$skip', 'maxItems': '100'},
        ),
        permissionDeniedAllowed: true,
      );
      if (response == null) {
        return hasDocumentReadAccess(
          node,
          authorities,
          membershipsKnown: false,
        );
      }
      final rows = response['list']['entries'] as List;
      authorities.addAll(rows.map((row) => row['entry']['id'] as String));
      if (response['list']['pagination']['hasMoreItems'] != true) break;
      if (rows.isEmpty) throw const FormatException('Invalid group pagination');
      skip += rows.length;
    }
    return hasDocumentReadAccess(node, authorities);
  }

  Future<WorkflowAssignee> _personReference(Map person) async {
    final username = person['userName'] as String;
    final escaped = username.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final response = await _post(
      'api/-default-/public/search/versions/1/search',
      {
        'query': {
          'query': 'TYPE:"cm:person" AND cm:userName:"$escaped"',
          'language': 'afts',
        },
        'paging': {'maxItems': 2},
      },
    );
    final rows = response['list']['entries'] as List;
    if (rows.length != 1) {
      throw const WorkflowStartNotSubmitted(
        'The selected user could not be resolved. Search again.',
      );
    }
    final display =
        [
          person['firstName'],
          person['lastName'],
        ].whereType<String>().join(' ').trim();
    return WorkflowAssignee(
      username,
      display.isEmpty ? username : display,
      'workspace://SpacesStore/${rows.single['entry']['id']}',
    );
  }

  @override
  Future<List<WorkflowAssignee>> searchAssignees(
    String nodeId,
    String query,
  ) async {
    if (query.trim().length < 2) return [];
    final node = await _startDocument(nodeId);
    final profile =
        (await _get(
          _uri('api/-default-/public/alfresco/versions/1/people/-me-'),
        ))!;
    final response =
        (await _get(
          _uri('s/api/people', {'filter': query.trim(), 'maxResults': '25'}),
        ))!;
    final result = <WorkflowAssignee>[];
    for (final raw in response['people'] as List) {
      final person = raw as Map;
      if (await _assigneeCanRead(
        node,
        person,
        profile['entry']['id'] as String,
      )) {
        result.add(await _personReference(person));
      }
    }
    return result;
  }

  @override
  Future<String> startWorkflow(
    WorkflowStartForm form,
    Map<String, String> values,
    WorkflowAssignee assignee,
  ) async {
    // All checks precede the one workflow mutation. No arbitrary URL or package is submitted.
    late final Map<String, dynamic> body;
    try {
      final definitions = await getStartDefinitions();
      if (!definitions.any(
        (d) =>
            d.id == form.definition.id &&
            d.name == form.definition.name &&
            d.supported,
      )) {
        throw const WorkflowStartNotSubmitted(
          'This workflow definition changed. Reopen the form.',
        );
      }
      final fresh = await getStartForm(form.definition, form.nodeId);
      if (fresh.fingerprint != form.fingerprint) {
        throw const WorkflowStartNotSubmitted(
          'The document or workflow form changed. Reopen the form.',
        );
      }
      final person =
          (await _get(
            _uri('s/api/people/${Uri.encodeComponent(assignee.username)}'),
          ))!;
      final profile =
          (await _get(
            _uri('api/-default-/public/alfresco/versions/1/people/-me-'),
          ))!;
      final node = await _startDocument(form.nodeId);
      if (!await _assigneeCanRead(
        node,
        person,
        profile['entry']['id'] as String,
      )) {
        throw const WorkflowStartNotSubmitted(
          'The selected user no longer has verified document access.',
        );
      }
      final resolved = await _personReference(person);
      body = fresh.submission(values, resolved);
    } on WorkflowStartNotSubmitted {
      rethrow;
    } catch (error) {
      // No workflow mutation has been sent when these checks fail.
      throw WorkflowStartNotSubmitted(error.toString());
    }
    final result = await _post(
      's/api/workflow/${Uri.encodeComponent(form.definition.name)}/formprocessor',
      body,
    );
    final id = RegExp(
      r'WorkflowInstance\[id=([^,]+)',
    ).firstMatch(result['persistedObject']?.toString() ?? '')?.group(1);
    if (id == null) {
      throw Exception(
        'Unable to confirm workflow creation. Check the server before starting another workflow.',
      );
    }
    final instance =
        (await _get(
          _uri('s/api/workflow-instances/${Uri.encodeComponent(id)}'),
        ))!;
    final package = instance['data']['package'] as String?;
    if (package == null) {
      throw Exception(
        'Workflow $id was created but its document could not be confirmed.',
      );
    }
    final contents =
        (await _get(
          _uri(
            'api/-default-/public/alfresco/versions/1/nodes/${Uri.encodeComponent(package.split('/').last)}/children',
            {'maxItems': '2'},
          ),
        ))!;
    final entries = contents['list']['entries'] as List;
    if (entries.length != 1 ||
        entries.single['entry']['id'] != form.nodeId ||
        contents['list']['pagination']['hasMoreItems'] == true) {
      throw Exception(
        'Workflow $id was created but its document could not be confirmed.',
      );
    }
    return id;
  }

  @override
  Future<void> changeOwnership(
    WorkflowTask snapshot, {
    required bool claim,
  }) async {
    final fresh = await getTask(snapshot.id);
    if (fresh == null ||
        !fresh.isActive ||
        fresh.owner != snapshot.owner ||
        fresh.isPooled != snapshot.isPooled ||
        fresh.isClaimable != snapshot.isClaimable ||
        fresh.isReleasable != snapshot.isReleasable ||
        (claim ? !fresh.isClaimable : !fresh.isReleasable)) {
      throw WorkflowTaskChanged();
    }
    final profile = await _get(
      _uri('api/-default-/public/alfresco/versions/1/people/-me-'),
    );
    final username = (profile?['entry'] as Map?)?['id'] as String?;
    if (username == null ||
        (!claim && fresh.owner != username) ||
        (claim && fresh.owner != null && fresh.owner!.isNotEmpty)) {
      throw WorkflowTaskChanged();
    }
    final taskId = fresh.id;
    if (!taskId.startsWith('activiti\$')) throw WorkflowTaskChanged();
    final response = await (client ?? appHttpClient)
        .put(
          _uri(
            'api/-default-/public/workflow/versions/1/tasks/${Uri.encodeComponent(taskId.substring(9))}',
            {'select': 'state'},
          ),
          headers: {
            'Authorization': authToken,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'state': claim ? 'claimed' : 'unclaimed'}),
        )
        .timeout(apiRequestTimeout);
    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please sign in again.');
    }
    if ([403, 404, 409].contains(response.statusCode)) {
      throw WorkflowTaskChanged();
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Unable to confirm task ownership. Refresh before trying again.',
      );
    }
    final result = await _get(
      _uri('s/api/task-instances/${Uri.encodeComponent(taskId)}'),
      missingAllowed: true,
    );
    if (result == null) throw WorkflowTaskChanged();
    final updated = WorkflowTask.fromJson(
      Map<String, dynamic>.from(result['data'] as Map),
    );
    if (!updated.isActive ||
        (claim
            ? updated.owner != username
            : (updated.owner?.isNotEmpty ?? false))) {
      throw Exception(
        'Unable to confirm task ownership. Refresh before trying again.',
      );
    }
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
    return Map<String, dynamic>.from(
      jsonDecode(
            path == 's/api/formdefinitions'
                ? _escapeFormControlCharacters(response.body)
                : response.body,
          )
          as Map,
    );
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
  Future<List<String>> getDocumentNames(WorkflowTask task) async =>
      (await getDocuments(task)).map((item) => item.name).toList();

  @override
  Future<List<BrowseItem>> getDocuments(WorkflowTask task) async {
    final package = task.packageNode;
    if (package == null || package.isEmpty) return [];
    final nodeId = package.split('/').last;
    final names = <BrowseItem>[];
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
          names.add(
            BrowseItem(
              id: entry['id'] as String,
              name: entry['name'] as String,
              type: 'file',
            ),
          );
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

// Some Alfresco 5.2 custom-model QName defaults contain literal XML whitespace
// emitted unescaped inside JSON strings. Preserve that data while escaping only
// control characters inside strings; all other malformed JSON still fails.
String _escapeFormControlCharacters(String source) {
  final result = StringBuffer();
  var inString = false, escaped = false;
  for (final code in source.codeUnits) {
    if (inString && code < 0x20) {
      result.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
      escaped = false;
      continue;
    }
    result.writeCharCode(code);
    if (escaped) {
      escaped = false;
    } else if (inString && code == 0x5c) {
      escaped = true;
    } else if (code == 0x22) {
      inString = !inString;
    }
  }
  return result.toString();
}
