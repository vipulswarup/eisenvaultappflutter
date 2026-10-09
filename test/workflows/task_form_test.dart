import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eisenvaultappflutter/models/account.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eisenvaultappflutter/models/workflow_task_form.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'package:eisenvaultappflutter/services/workflows/workflow_draft_store.dart';
import 'package:eisenvaultappflutter/screens/workflows/workflow_task_actions.dart';

Map<String, dynamic> task({bool completed = false}) => {
  'id': 'activiti\$test',
  'name': 'wf:adhocTask',
  'state': completed ? 'COMPLETED' : 'IN_PROGRESS',
  'isEditable': !completed,
  'isPooled': false,
  'workflowInstance': {'name': 'activiti\$activitiAdhoc'},
  'definition': {
    'node': {
      'transitions': [
        {'id': 'Next', 'title': 'Task Done', 'isHidden': false},
      ],
    },
  },
};
Map<String, dynamic> field(
  String name,
  String type, {
  bool required = true,
  List<Map>? constraints,
}) => {
  'name': name,
  'label': name,
  'dataKeyName': 'prop_${name.replaceAll(':', '_')}',
  'type': 'property',
  'dataType': type,
  'mandatory': required,
  'protectedField': false,
  if (constraints != null) 'constraints': constraints,
};
Map<String, dynamic> formData() => {
  'definition': {
    'fields': [
      field(
        'bpm:percentComplete',
        'int',
        constraints: [
          {
            'type': 'MINMAX',
            'parameters': {'minValue': 0, 'maxValue': 100},
          },
        ],
      ),
      field(
        'bpm:status',
        'text',
        constraints: [
          {
            'type': 'LIST',
            'parameters': {
              'allowedValues': [
                'Not Yet Started|Not Yet Started',
                'Completed|Completed',
              ],
            },
          },
        ],
      ),
      field(
        'bpm:comment',
        'text',
        required: false,
        constraints: [
          {
            'type': 'LENGTH',
            'parameters': {'maxLength': 4000},
          },
        ],
      ),
      field('custom:optional', 'text', required: false),
    ],
  },
  'formData': {
    'prop_bpm_percentComplete': 0,
    'prop_bpm_status': 'Not Yet Started',
    'prop_bpm_comment': '',
  },
};
WorkflowTaskForm model() =>
    WorkflowTaskForm.fromJson('activiti\$test', task(), formData());

class ActionsFake implements WorkflowActionService {
  WorkflowTaskForm current = model();
  Map<String, String>? submitted;
  @override
  Future<WorkflowTaskForm> getTaskForm(String id) async => current;
  @override
  Future<void> completeTask(
    WorkflowTaskForm form,
    Map<String, String> values,
    String transition,
  ) async {
    submitted = values;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'server constraints, typed values, optional fields and unsupported mandatory controls',
    () {
      final f = model();
      final values = f.initialValues;
      expect(f.fields.any((f) => f.name == 'custom:optional'), isFalse);
      expect(f.submission(values, 'Next')['prop_bpm_percentComplete'], 0);
      values['prop_bpm_percentComplete'] = '101';
      expect(() => f.submission(values, 'Next'), throwsFormatException);
      values['prop_bpm_percentComplete'] = 'bad';
      expect(() => f.submission(values, 'Next'), throwsFormatException);
      values['prop_bpm_percentComplete'] = '50';
      values['prop_bpm_status'] = 'Invented';
      expect(() => f.submission(values, 'Next'), throwsFormatException);
      final raw = formData();
      (raw['definition']['fields'] as List).add(
        field('custom:required', 'unknown'),
      );
      expect(
        WorkflowTaskForm.fromJson('id', task(), raw).unavailableReason,
        contains('unsupported control'),
      );
      final signature = task()..['name'] = 'scwf:activitiReviewTask';
      expect(
        WorkflowTaskForm.fromJson(
          'id',
          signature,
          formData(),
        ).unavailableReason,
        isNotNull,
      );
    },
  );

  test(
    'refreshes before submission and posts exactly once; verifies completion',
    () async {
      var completed = false;
      var submissions = 0;
      final service = AlfrescoWorkflowService(
        baseUrl: 'https://server/alfresco',
        authToken: 'ticket',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/formprocessor')) {
            submissions++;
            expect(jsonDecode(request.body)['prop_transitions'], 'Next');
            expect(jsonDecode(request.body)['prop_bpm_percentComplete'], 100);
            completed = true;
            return http.Response('{}', 200);
          }
          if (request.url.path.endsWith('/formdefinitions')) {
            return http.Response(jsonEncode({'data': formData()}), 200);
          }
          if (request.url.path.endsWith('/task-instances')) {
            return http.Response(
              jsonEncode({
                'data':
                    completed ||
                            request.url.queryParameters['pooledTasks'] == 'true'
                        ? []
                        : [task()],
                'paging': {'totalItems': completed ? 0 : 1},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'data': task(completed: completed)}),
            200,
          );
        }),
      );
      final form = await service.getTaskForm('activiti\$test');
      await service.completeTask(form, {
        ...form.initialValues,
        'prop_bpm_percentComplete': '100',
      }, 'Next');
      expect(submissions, 1);
    },
  );

  test('concurrent changes block mutation', () async {
    var changed = false;
    var submissions = 0;
    final service = AlfrescoWorkflowService(
      baseUrl: 'https://server/alfresco',
      authToken: 'ticket',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/formprocessor')) {
          submissions++;
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/formdefinitions')) {
          final f = formData();
          if (changed) {
            f['formData']['prop_bpm_comment'] = 'Another client edited this';
          }
          return http.Response(jsonEncode({'data': f}), 200);
        }
        if (request.url.path.endsWith('/task-instances')) {
          return http.Response(
            jsonEncode({
              'data': [task()],
              'paging': {'totalItems': 1},
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'data': task()}), 200);
      }),
    );
    final form = await service.getTaskForm('activiti\$test');
    changed = true;
    await expectLater(
      service.completeTask(form, form.initialValues, 'Next'),
      throwsA(isA<WorkflowTaskChanged>()),
    );
    expect(submissions, 0);
  });

  test(
    'drafts isolate accounts and sign-out deletes only that account',
    () async {
      final a = WorkflowDraftStore('a', 'task'),
          b = WorkflowDraftStore('b', 'task');
      await a.save('snapshot', {'comment': 'account A'});
      await b.save('snapshot', {'comment': 'account B'});
      await WorkflowDraftStore.clearAccount('a');
      expect(await a.read(), isNull);
      expect((await b.read())!['values']['comment'], 'account B');
    },
  );

  testWidgets(
    'saved comments survive reopening and completion clears the draft',
    (tester) async {
      final service = ActionsFake();
      Widget screen() => MaterialApp(
        home: Scaffold(
          body: WorkflowTaskActions(
            service: service,
            taskId: 'activiti\$test',
            accountId: 'a',
            onCompleted: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'Draft comment');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('Draft comment'), findsOneWidget);
      await tester.tap(find.text('Task Done'));
      await tester.pumpAndSettle();
      expect(service.submitted!['prop_bpm_comment'], 'Draft comment');
      expect(await WorkflowDraftStore('a', 'activiti\$test').read(), isNull);
    },
  );
  test(
    'switching accounts keeps drafts; sign-out removes account drafts',
    () async {
      Account account(String user) => Account.fromCredentials(
        username: user,
        firstName: user,
        instanceType: 'Classic',
        baseUrl: 'https://server/alfresco',
        customerHostname: 'server',
        token: 'test-token',
      );
      final a = account('a'), b = account('b');
      FlutterSecureStorage.setMockInitialValues({
        'multi_accounts': jsonEncode([a.toJson(), b.toJson()]),
        'active_account_id': a.id,
      });
      final auth = AuthStateManager();
      await auth.initialize();
      final draftA = WorkflowDraftStore(a.id, 'task'),
          draftB = WorkflowDraftStore(b.id, 'task');
      await draftA.save('snapshot', {'comment': 'A'});
      await draftB.save('snapshot', {'comment': 'B'});
      expect(await auth.switchAccount(b.id), isTrue);
      expect(await draftA.read(), isNotNull);
      expect(await draftB.read(), isNotNull);
      expect(await auth.removeAccount(b.id), isTrue);
      expect(await draftB.read(), isNull);
      expect(await draftA.read(), isNotNull);
      await auth.logoutAll();
      expect(await draftA.read(), isNull);
    },
  );

  testWidgets('stale task discards drafts and disables completion', (
    tester,
  ) async {
    final service = ChangedActionsFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkflowTaskActions(
            service: service,
            taskId: 'activiti\$test',
            accountId: 'a',
            onCompleted: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Stale comment');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task Done'));
    await tester.pumpAndSettle();
    expect(find.text('Task Done'), findsNothing);
    expect(find.textContaining('no longer assigned'), findsWidgets);
    expect(await WorkflowDraftStore('a', 'activiti\$test').read(), isNull);
  });
}

class ChangedActionsFake extends ActionsFake {
  bool changed = false;
  @override
  Future<WorkflowTaskForm> getTaskForm(String id) async {
    if (changed) throw WorkflowTaskChanged();
    return current;
  }

  @override
  Future<void> completeTask(
    WorkflowTaskForm form,
    Map<String, String> values,
    String transition,
  ) async {
    changed = true;
    throw WorkflowTaskChanged();
  }
}
