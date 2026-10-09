import 'dart:convert';
import 'package:eisenvaultappflutter/screens/workflows/start_workflow_screen.dart';
import 'package:eisenvaultappflutter/models/workflow_start_form.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const base = String.fromEnvironment('WORKFLOW_TEST_URL');
  const auth = String.fromEnvironment('WORKFLOW_TEST_AUTH');
  const nodeId = String.fromEnvironment('WORKFLOW_GROUP_TEST_NODE_ID');
  const nodeName = String.fromEnvironment('WORKFLOW_GROUP_TEST_NODE_NAME');

  testWidgets('starts pooled review from UI with an eligible group', (
    tester,
  ) async {
    final client = http.Client();
    final service = AlfrescoWorkflowService(
      baseUrl: base,
      authToken: auth,
      client: client,
    );
    String? workflowId;
    try {
      final nodeResponse = await client.get(
        Uri.parse(
          '$base/api/-default-/public/alfresco/versions/1/nodes/$nodeId?include=permissions',
        ),
        headers: {'Authorization': auth},
      );
      final node = jsonDecode(nodeResponse.body)['entry'];
      expect(node['name'], nodeName);
      expect(
        node['permissions']['locallySet'],
        contains(containsPair('authorityId', 'GROUP_ALFRESCO_ADMINISTRATORS')),
      );
      final definitions = await service.getStartDefinitions();
      final pooled = definitions.singleWhere(
        (d) => d.name == 'activiti\$activitiReviewPooled',
      );
      final startForm = await service.getStartForm(pooled, nodeId);
      expect(startForm.unavailableReason, isNull);
      expect(
        () => startForm.submission(
          startForm.initialValues,
          const WorkflowAssignee(
            'GROUP_ALFRESCO_ADMINISTRATORS',
            'Administrators',
            'GROUP_ALFRESCO_ADMINISTRATORS',
            isGroup: true,
          ),
        ),
        returnsNormally,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () async {
                        workflowId = await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder:
                                (_) => StartWorkflowScreen(
                                  service: service,
                                  nodeId: nodeId,
                                  documentName: nodeName,
                                  accountId: 'native-pooled-start-test',
                                ),
                          ),
                        );
                      },
                      child: const Text('Open workflow form'),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Open workflow form'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(pooled.title).last);
      await tester.pumpAndSettle();

      final assignee = find.text('Search groups with an eligible member');
      await tester.ensureVisible(assignee);
      await tester.tap(assignee);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'ALFRESCO_ADMINISTRATORS',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Search'));
      for (
        var i = 0;
        i < 60 && find.text('ALFRESCO_ADMINISTRATORS').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('ALFRESCO_ADMINISTRATORS'), findsWidgets);
      await tester.tap(find.text('ALFRESCO_ADMINISTRATORS').last);
      await tester.pumpAndSettle();
      final assigneeField = find.byWidgetPredicate(
        (widget) => widget is FormField<WorkflowAssignee>,
      );
      final selectedAssignee =
          tester.state<FormFieldState<WorkflowAssignee>>(assigneeField).value;
      expect(selectedAssignee?.isGroup, isTrue);
      final formValid = tester.state<FormState>(find.byType(Form)).validate();
      expect(
        formValid,
        isTrue,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' | '),
      );
      final startButton = find.widgetWithText(FilledButton, 'Start workflow');
      await tester.scrollUntilVisible(
        startButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(startButton);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(startButton).onPressed, isNotNull);
      await tester.tap(startButton);
      await tester.pump();
      expect(find.text('Starting…'), findsOneWidget);
      for (var i = 0; i < 450 && workflowId == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final uiText = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' | ');
      final inputs =
          tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .map((f) => f.controller?.text ?? f.initialValue ?? '')
              .toList();
      expect(workflowId, isNotNull, reason: 'UI=$uiText; inputs=$inputs');

      final tasksResponse = await client.get(
        Uri.parse(
          '$base/s/api/workflow-instances/${Uri.encodeComponent(workflowId!)}/task-instances',
        ),
        headers: {'Authorization': auth},
      );
      expect(tasksResponse.statusCode, 200);
      final tasks = jsonDecode(tasksResponse.body)['data'] as List;
      final review =
          tasks.where((t) => t['name'] == 'wf:activitiReviewTask').toList();
      expect(review, hasLength(1));
      expect(review.single['isPooled'], isTrue);
      expect(review.single['state'], 'IN_PROGRESS');
    } finally {
      if (workflowId != null) {
        await client.delete(
          Uri.parse(
            '$base/s/api/workflow-instances/${Uri.encodeComponent(workflowId!)}?forced=true',
          ),
          headers: {'Authorization': auth},
        );
      }
      if (nodeId.isNotEmpty) {
        final response = await client.get(
          Uri.parse(
            '$base/api/-default-/public/alfresco/versions/1/nodes/$nodeId',
          ),
          headers: {'Authorization': auth},
        );
        if (response.statusCode == 200 &&
            jsonDecode(response.body)['entry']['name'] == nodeName) {
          await client.delete(
            Uri.parse(
              '$base/api/-default-/public/alfresco/versions/1/nodes/$nodeId',
            ),
            headers: {'Authorization': auth},
          );
        }
      }
      client.close();
    }
  }, skip: base.isEmpty || auth.isEmpty || nodeId.isEmpty || nodeName.isEmpty);
}
