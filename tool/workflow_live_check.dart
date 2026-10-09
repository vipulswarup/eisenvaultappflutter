// Opt-in live verification. Credentials are read from stdin, never printed.
// dart run tool/workflow_live_check.dart <alfresco-url> <test-task-id> [--complete]
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Provide an Alfresco URL and test task ID. Username and password are read from stdin.',
    );
  }
  final username = stdin.readLineSync()!;
  final password = stdin.readLineSync()!;
  final base = args[0].replaceAll(RegExp(r'/+$'), '');
  final client = http.Client();
  try {
    final response = await client.post(
      Uri.parse('$base/api/-default-/public/authentication/versions/1/tickets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': username, 'password': password}),
    );
    if (response.statusCode != 201) {
      throw StateError('Authentication failed (HTTP ${response.statusCode})');
    }
    final ticket = jsonDecode(response.body)['entry']['id'] as String;
    final auth = 'Basic ${base64Encode(utf8.encode(ticket))}';
    final service = AlfrescoWorkflowService(
      baseUrl: base,
      authToken: auth,
      client: client,
    );
    final tasks = await service.getMyTasks();
    stdout.writeln('Visible active tasks: ${tasks.length}');
    final task = await service.getTask(args[1]);
    if (task == null || !task.isActive) {
      throw StateError('Test task is unavailable');
    }
    stdout.writeln('Task documents: ${await service.getDocumentNames(task)}');
    final form = await service.getTaskForm(task.id);
    if (form.unavailableReason != null) {
      throw StateError(form.unavailableReason!);
    }
    stdout.writeln(
      'Supported form: ${form.fields.length} fields; actions: ${form.transitions.values.join(', ')}',
    );
    if (args.contains('--complete')) {
      final detail = await client.get(
        Uri.parse('$base/s/api/task-instances/${Uri.encodeComponent(task.id)}'),
        headers: {'Authorization': auth},
      );
      final message =
          jsonDecode(detail.body)['data']['workflowInstance']['message']
              as String? ??
          '';
      if (!message.startsWith('Codex workflow completion test')) {
        throw StateError(
          'Only dedicated Codex test workflows may be mutated by this tool',
        );
      }
      final values = form.initialValues;
      values['prop_bpm_percentComplete'] = '100';
      values['prop_bpm_status'] = 'Completed';
      values['prop_bpm_comment'] = 'Verified through Flutter workflow service';
      await service.completeTask(form, values, 'Next');
      if ((await service.getMyTasks()).any((t) => t.id == task.id)) {
        throw StateError('Completed task still appears in My Tasks');
      }
      stdout.writeln('PASS: completion confirmed and task removed from My Tasks');
    }
  } finally {
    client.close();
  }
}
