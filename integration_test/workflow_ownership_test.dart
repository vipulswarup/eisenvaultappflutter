import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/screens/workflows/my_tasks_screen.dart';
import 'package:eisenvaultappflutter/screens/workflows/workflow_task_actions.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'package:eisenvaultappflutter/services/workflows/workflow_draft_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const base = String.fromEnvironment('WORKFLOW_TEST_URL');
  const auth = String.fromEnvironment('WORKFLOW_TEST_AUTH');
  const id = String.fromEnvironment('WORKFLOW_TEST_TASK_ID');
  const competitor = String.fromEnvironment('WORKFLOW_TEST_COMPETITOR');
  testWidgets(
    'macOS group claim, release confirmation, refresh and conflicting claim',
    (tester) async {
      final client = http.Client();
      final service = AlfrescoWorkflowService(
        baseUrl: base,
        authToken: auth,
        client: client,
      );
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 3)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(String label) async {
        if (find.text(label).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text(label),
            -250,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await settle();
      }

      Future<void> setOwner(String? owner) async {
        final response = await client.put(
          Uri.parse('$base/s/api/task-instances/${Uri.encodeComponent(id)}'),
          headers: {'Authorization': auth, 'Content-Type': 'application/json'},
          body: jsonEncode({'cm_owner': owner}),
        );
        expect(response.statusCode, 200);
      }

      final initial = (await service.getTask(id))!;
      expect(initial.summary, startsWith('codex_claim_'));
      try {
        expect(initial.isClaimable, isTrue);
        await tester.pumpWidget(
          MaterialApp(
            home: WorkflowTaskScreen(
              service: service,
              taskId: id,
              accountId: 'native-ownership-test',
            ),
          ),
        );
        await settle();
        await tap('Claim task');
        expect((await service.getTask(id))!.owner, 'admin');
        expect(find.text('Release task'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byType(WorkflowTaskActions),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await settle();
        expect(find.text('Approve'), findsOneWidget);
        await tap('Release task');
        expect(find.text('Release task?'), findsOneWidget);
        await tap('Cancel');
        expect((await service.getTask(id))!.owner, 'admin');
        await tap('Release task');
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Release'),
          ),
        );
        await settle();
        expect((await service.getTask(id))!.owner, isNull);
        expect(find.text('Claim task'), findsOneWidget);
        expect(find.text('Approve'), findsNothing);
        // Simulate another member taking ownership after the UI loaded.
        final stale = (await service.getTask(id))!;
        await setOwner(competitor);
        await expectLater(
          service.changeOwnership(stale, claim: true),
          throwsA(isA<WorkflowTaskChanged>()),
        );
        // Verify the server also rejects an atomic claim of an already-owned task.
        final response = await client.put(
          Uri.parse(
            '$base/api/-default-/public/workflow/versions/1/tasks/${id.substring(9)}?select=state',
          ),
          headers: {'Authorization': auth, 'Content-Type': 'application/json'},
          body: '{"state":"claimed"}',
        );
        expect(response.statusCode, 409);
      } finally {
        await setOwner(null);
        await WorkflowDraftStore.clearAccount('native-ownership-test');
        client.close();
      }
    },
    skip: base.isEmpty || auth.isEmpty || id.isEmpty || competitor.isEmpty,
  );
}
