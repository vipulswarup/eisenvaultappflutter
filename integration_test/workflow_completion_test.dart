// Opt-in native test against an explicitly configured non-production server.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/screens/workflows/my_tasks_screen.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'package:eisenvaultappflutter/services/workflows/workflow_draft_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const base = String.fromEnvironment('WORKFLOW_TEST_URL');
  const username = String.fromEnvironment('WORKFLOW_TEST_USER');
  const password = String.fromEnvironment('WORKFLOW_TEST_PASSWORD');
  testWidgets('macOS: open task, save comment, complete and refresh My Tasks', (
    tester,
  ) async {
    if (base.isEmpty || username.isEmpty || password.isEmpty) {
      throw StateError('Explicit test server configuration is required');
    }
    final client = http.Client();
    String? nodeId, workflowId;
    const accountId = 'native-workflow-test';
    var auth = '';
    Future<Map<String, dynamic>> request(
      String path, {
      String method = 'GET',
      Map<String, dynamic>? body,
    }) async {
      final req = http.Request(method, Uri.parse('$base/$path'));
      req.headers.addAll({
        'Content-Type': 'application/json',
        if (auth.isNotEmpty) 'Authorization': auth,
      });
      if (body != null) req.body = jsonEncode(body);
      final r = await http.Response.fromStream(
        await client.send(req),
      ).timeout(const Duration(seconds: 30));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw StateError(
          'Fixture request failed: $method $path HTTP ${r.statusCode}',
        );
      }
      return r.body.isEmpty
          ? {}
          : Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    }

    try {
      final ticket =
          (await request(
                'api/-default-/public/authentication/versions/1/tickets',
                method: 'POST',
                body: {'userId': username, 'password': password},
              ))['entry']['id']
              as String;
      auth = 'Basic ${base64Encode(utf8.encode(ticket))}';
      final people = await request(
        'api/-default-/public/search/versions/1/search',
        method: 'POST',
        body: {
          'query': {
            'query': 'TYPE:"cm:person" AND cm:userName:"$username"',
            'language': 'afts',
          },
        },
      );
      final personId = people['list']['entries'].first['entry']['id'] as String;
      final marker =
          'Codex workflow completion test ${DateTime.now().millisecondsSinceEpoch}';
      final node = await request(
        'api/-default-/public/alfresco/versions/1/nodes/-my-/children',
        method: 'POST',
        body: {'name': '$marker.txt', 'nodeType': 'cm:content'},
      );
      nodeId = node['entry']['id'] as String;
      final start = await request(
        's/api/workflow/activiti%24activitiAdhoc/formprocessor',
        method: 'POST',
        body: {
          'assoc_bpm_assignee_added': 'workspace://SpacesStore/$personId',
          'assoc_packageItems_added': 'workspace://SpacesStore/$nodeId',
          'prop_bpm_workflowDescription': marker,
          'prop_bpm_status': 'Not Yet Started',
          'prop_bpm_percentComplete': 0,
          'prop_bpm_workflowPriority': 2,
          'prop_wf_notifyMe': false,
          'prop_bpm_sendEMailNotifications': false,
        },
      );
      workflowId = RegExp(
        r'WorkflowInstance\[id=([^,]+)',
      ).firstMatch(start['persistedObject'] as String)!.group(1);
      final service = AlfrescoWorkflowService(
        baseUrl: base,
        authToken: auth,
        client: client,
      );
      final tasks = await service.getMyTasks();
      final task = tasks.singleWhere((t) => t.summary == marker);
      expect(await service.getDocumentNames(task), ['$marker.txt']);
      await tester.pumpWidget(
        MaterialApp(
          home: MyTasksScreen(
            service: service,
            accountId: accountId,
            accountLabel: 'Native test account',
          ),
        ),
      );
      // Native HTTP runs outside the test's simulated clock.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(marker),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(marker));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 3));
      });
      await tester.pumpAndSettle();
      expect(find.text('Task details'), findsOneWidget);
      expect(find.text('$marker.txt'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Task Done'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Completed through macOS UI test',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task Done'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 4));
      });
      await tester.pumpAndSettle();
      expect(find.text('My Tasks'), findsOneWidget);
      expect((await service.getMyTasks()).any((t) => t.id == task.id), isFalse);
      expect(await WorkflowDraftStore(accountId, task.id).read(), isNull);
    } finally {
      await WorkflowDraftStore.clearAccount(accountId);
      if (workflowId != null) {
        await request(
          's/api/workflow-instances/${Uri.encodeComponent(workflowId)}',
          method: 'DELETE',
        );
      }
      if (nodeId != null) {
        await request(
          'api/-default-/public/alfresco/versions/1/nodes/$nodeId',
          method: 'DELETE',
        );
      }
      client.close();
    }
  });
}
