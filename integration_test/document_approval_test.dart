import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/screens/workflows/my_tasks_screen.dart';
import 'package:eisenvaultappflutter/screens/workflows/workflow_task_actions.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'package:eisenvaultappflutter/services/workflows/workflow_draft_store.dart';

class ReadOnlyTestClient extends http.BaseClient {
  final http.Client inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.method != 'GET' &&
        !request.url.path.endsWith('/formdefinitions')) {
      throw StateError('Read-only test cannot mutate existing workflows');
    }
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const base = String.fromEnvironment('WORKFLOW_TEST_URL');
  const auth = String.fromEnvironment('WORKFLOW_TEST_AUTH');
  testWidgets(
    'deployed Document Approval form loads and rejection can be cancelled',
    (tester) async {
      final client = ReadOnlyTestClient();
      final service = AlfrescoWorkflowService(
        baseUrl: base,
        authToken: auth,
        client: client,
      );
      try {
        final response = await client.get(
          Uri.parse(
            '$base/s/api/task-instances?authority=admin&state=IN_PROGRESS',
          ),
          headers: {'Authorization': auth},
        );
        final row = (jsonDecode(response.body)['data'] as List).firstWhere(
          (t) => t['workflowInstance']['name'] == 'activiti\$docApproveReject',
        );
        final form = await service.getTaskForm(row['id']);
        expect(form.unavailableReason, isNull);
        expect(form.actions.map((a) => a.id), ['Approve', 'Reject']);
        await tester.pumpWidget(
          MaterialApp(
            home: WorkflowTaskScreen(
              service: service,
              taskId: row['id'],
              accountId: 'native-document-approval-test',
            ),
          ),
        );
        Future<void> settle() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();
        }

        await settle();
        await tester.scrollUntilVisible(
          find.widgetWithText(OutlinedButton, 'Reject'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
        await tester.pumpAndSettle();
        expect(find.text('Reject task?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      } finally {
        await WorkflowDraftStore.clearAccount('native-document-approval-test');
        client.close();
      }
    },
    skip: base.isEmpty || auth.isEmpty,
  );
  const document = String.fromEnvironment('WORKFLOW_CUSTOM_NODE');
  const approveTask = String.fromEnvironment('WORKFLOW_CUSTOM_APPROVE_TASK');
  const rejectTask = String.fromEnvironment('WORKFLOW_CUSTOM_REJECT_TASK');
  for (final action in ['Approve', 'Reject']) {
    testWidgets(
      'disposable Document Approval $action completes with the recorded outcome',
      (tester) async {
        final taskId = action == 'Approve' ? approveTask : rejectTask;
        final client = http.Client();
        final service = AlfrescoWorkflowService(
          baseUrl: base,
          authToken: auth,
          client: client,
        );
        try {
          // Never allow this mutation test to act on an ordinary user's task.
          final task = await service.getTask(taskId);
          expect(task, isNotNull);
          expect(task!.summary, 'Codex approval validation');
          final documents = await service.getDocuments(task);
          expect(documents.single.id, document);
          expect(
            documents.single.name,
            startsWith('Codex approval validation'),
          );
          var completed = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: WorkflowTaskActions(
                    service: service,
                    taskId: taskId,
                    accountId: 'native-document-approval-mutation',
                    onCompleted: (result) {
                      expect(result, action);
                      completed = true;
                    },
                  ),
                ),
              ),
            ),
          );
          Future<void> settle() async {
            for (var i = 0; i < 30; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)),
              );
              await tester.pump();
            }
            await tester.pumpAndSettle();
          }

          await settle();
          final button =
              action == 'Approve'
                  ? find.widgetWithText(FilledButton, action)
                  : find.widgetWithText(OutlinedButton, action);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          if (action == 'Reject') {
            expect(find.text('Reject task?'), findsOneWidget);
            await tester.tap(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.text('Reject'),
              ),
            );
          }
          await settle();
          expect(completed, isTrue);
          final response = await client.get(
            Uri.parse(
              '$base/s/api/task-instances/${Uri.encodeComponent(taskId)}',
            ),
            headers: {'Authorization': auth},
          );
          final data = jsonDecode(response.body)['data'];
          expect(data['state'], 'COMPLETED');
          expect(data['properties']['scwf_approveRejectOutcome'], action);
        } finally {
          await WorkflowDraftStore.clearAccount(
            'native-document-approval-mutation',
          );
          client.close();
        }
      },
      skip:
          base.isEmpty ||
          auth.isEmpty ||
          document.isEmpty ||
          approveTask.isEmpty ||
          rejectTask.isEmpty,
    );
  }
}
