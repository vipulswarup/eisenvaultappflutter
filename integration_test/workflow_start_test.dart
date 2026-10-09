import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:eisenvaultappflutter/screens/workflows/start_workflow_screen.dart';
import 'package:eisenvaultappflutter/models/workflow_start_form.dart';
import 'package:eisenvaultappflutter/services/auth/classic_auth_service.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'package:eisenvaultappflutter/services/workflows/workflow_draft_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const base = String.fromEnvironment('WORKFLOW_TEST_URL');
  const node = String.fromEnvironment('WORKFLOW_TEST_NODE_ID');
  const name = String.fromEnvironment('WORKFLOW_TEST_NODE_NAME');
  const user = String.fromEnvironment('WORKFLOW_REVIEWER_USER');
  const password = String.fromEnvironment('WORKFLOW_REVIEWER_PASSWORD');
  const consumerUser = String.fromEnvironment('WORKFLOW_CONSUMER_USER');
  const consumerPassword = String.fromEnvironment('WORKFLOW_CONSUMER_PASSWORD');
  for (final workflow in [
    'activiti\$activitiAdhoc',
    'activiti\$activitiReview',
  ]) {
    testWidgets(
      'macOS document starts $workflow and read-only assignee completes it',
      (tester) async {
        final client = http.Client();
        final login = await ClassicAuthService(
          base,
          client: client,
        ).login(user, password);
        final receiverLogin = await ClassicAuthService(
          base,
          client: client,
        ).login(consumerUser, consumerPassword);
        final service = AlfrescoWorkflowService(
          baseUrl: base,
          authToken: login['token'],
          client: client,
        );
        final receiver = AlfrescoWorkflowService(
          baseUrl: base,
          authToken: receiverLogin['token'],
          client: client,
        );
        final definitions = await service.getStartDefinitions();
        final definition = definitions.singleWhere((d) => d.name == workflow);
        final marker =
            'Codex workflow start test ${DateTime.now().millisecondsSinceEpoch}';
        String? created;
        Future<void> settle() async {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 3)),
          );
          await tester.pumpAndSettle();
        }

        try {
          final form = await service.getStartForm(definition, node);
          expect(form.documentName, startsWith('Codex workflow start test'));
          expect(form.unavailableReason, isNull);
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder:
                    (context) => Scaffold(
                      body: TextButton(
                        onPressed: () async {
                          created = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => StartWorkflowScreen(
                                    service: service,
                                    nodeId: node,
                                    documentName: name,
                                    accountId: 'native-start-test',
                                  ),
                            ),
                          );
                        },
                        child: const Text('Open document workflow'),
                      ),
                    ),
              ),
            ),
          );
          await tester.tap(find.text('Open document workflow'));
          await settle();
          await tester.tap(find.byType(DropdownButtonFormField<String>).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(definition.title).last);
          await settle();
          await tester.tap(find.text('Search users with document access'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextField, 'Search users'),
            'vipul',
          );
          await tester.tap(find.text('Search'));
          await settle();
          expect(find.text(consumerUser), findsOneWidget);
          await tester.tap(find.text(consumerUser));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('1:prop_bpm_workflowDescription')),
            marker,
          );
          await tester.ensureVisible(find.byTooltip('Choose due date'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Choose due date'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.widgetWithText(FilledButton, 'Start workflow'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Start workflow'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Start workflow'));
          await settle();
          expect(created, isNotNull);
          expect(find.text('Open document workflow'), findsOneWidget);
          final task = (await receiver.getMyTasks()).singleWhere(
            (t) => t.summary == marker,
          );
          expect(await receiver.getDocumentNames(task), [name]);
          expect(task.dueDate, isNotNull);
          final completion = await receiver.getTaskForm(task.id);
          expect(completion.unavailableReason, isNull);
          await receiver.completeTask(
            completion,
            completion.initialValues,
            workflow.endsWith('Review') ? 'Approve' : 'Next',
          );
          expect(
            (await receiver.getMyTasks()).any((t) => t.id == task.id),
            isFalse,
          );
          expect(
            await WorkflowDraftStore(
              'native-start-test',
              'start:$node:${definition.id}',
            ).read(),
            isNull,
          );
        } finally {
          // Discover a submitted fixture even if confirmation was interrupted.
          final tasks = await receiver.getMyTasks();
          final fixture = tasks.where((t) => t.summary == marker).firstOrNull;
          String? workflowId = created;
          if (workflowId == null && fixture != null) {
            final response = await client.get(
              Uri.parse(
                '$base/s/api/task-instances/${Uri.encodeComponent(fixture.id)}',
              ),
              headers: {'Authorization': receiverLogin['token']},
            );
            workflowId =
                jsonDecode(response.body)['data']['workflowInstance']['id'];
          }
          if (workflowId != null) {
            final admin = await ClassicAuthService(base, client: client).login(
              const String.fromEnvironment('WORKFLOW_TEST_USER'),
              const String.fromEnvironment('WORKFLOW_TEST_PASSWORD'),
            );
            final response = await client.delete(
              Uri.parse(
                '$base/s/api/workflow-instances/${Uri.encodeComponent(workflowId)}',
              ),
              headers: {'Authorization': admin['token']},
            );
            expect(response.statusCode, 200);
          }
          await WorkflowDraftStore.clearAccount('native-start-test');
          client.close();
        }
      },
      skip: base.isEmpty || node.isEmpty,
    );
  }
  testWidgets(
    'consumer self-access and revoked document permission are checked',
    (tester) async {
      final client = http.Client();
      final admin = await ClassicAuthService(base, client: client).login(
        const String.fromEnvironment('WORKFLOW_TEST_USER'),
        const String.fromEnvironment('WORKFLOW_TEST_PASSWORD'),
      );
      final login = await ClassicAuthService(
        base,
        client: client,
      ).login(user, password);
      final consumer = await ClassicAuthService(
        base,
        client: client,
      ).login(consumerUser, consumerPassword);
      final service = AlfrescoWorkflowService(
        baseUrl: base,
        authToken: login['token'],
        client: client,
      );
      final receiver = AlfrescoWorkflowService(
        baseUrl: base,
        authToken: consumer['token'],
        client: client,
      );
      final people = await receiver.searchAssignees(node, 'vipul');
      expect(people.map((p) => p.username), [consumerUser]);
      final candidates = await service.searchAssignees(node, consumerUser);
      final definition = (await service.getStartDefinitions()).singleWhere(
        (d) => d.name == 'activiti\$activitiReview',
      );
      final form = await service.getStartForm(definition, node);
      expect(form.documentName, startsWith('Codex workflow start test'));
      Future<void> permissions(bool includeConsumer) async {
        final response = await client.put(
          Uri.parse(
            '$base/api/-default-/public/alfresco/versions/1/nodes/$node',
          ),
          headers: {
            'Authorization': admin['token'],
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'permissions': {
              'isInheritanceEnabled': false,
              'locallySet': [
                {
                  'authorityId': user,
                  'name': 'Collaborator',
                  'accessStatus': 'ALLOWED',
                },
                if (includeConsumer)
                  {
                    'authorityId': consumerUser,
                    'name': 'Consumer',
                    'accessStatus': 'ALLOWED',
                  },
              ],
            },
          }),
        );
        expect(response.statusCode, 200);
      }

      try {
        await permissions(false);
        await expectLater(
          service.startWorkflow(form, form.initialValues, candidates.single),
          throwsA(isA<WorkflowStartNotSubmitted>()),
        );
        expect(await service.searchAssignees(node, consumerUser), isEmpty);
      } finally {
        await permissions(true);
        client.close();
      }
    },
    skip: base.isEmpty || node.isEmpty,
  );
}
