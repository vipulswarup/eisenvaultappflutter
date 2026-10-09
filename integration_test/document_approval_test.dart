import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/screens/workflows/my_tasks_screen.dart';
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
}
