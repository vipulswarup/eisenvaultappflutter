import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eisenvaultappflutter/models/workflow_task_form.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'package:eisenvaultappflutter/screens/workflows/workflow_task_actions.dart';
import 'task_form_test.dart' as fixture;

Map<String, dynamic> reviewTask({
  bool completed = false,
  String outcome = 'Reject',
}) =>
    fixture.task(completed: completed)
      ..['name'] = 'wf:activitiReviewTask'
      ..['properties'] = {
        'bpm_outcomePropertyName': 'wf:reviewOutcome',
        'wf_reviewOutcome': outcome,
      }
      ..['workflowInstance'] = {'name': 'activiti\$activitiReview'};
Map<String, dynamic> reviewForm({bool requiredComment = false}) {
  final form = fixture.formData();
  (form['definition']['fields'] as List).add(
    fixture.field(
      'wf:reviewOutcome',
      'text',
      required: false,
      constraints: [
        {
          'type': 'LIST',
          'parameters': {
            'allowedValues': ['Approve|Approve', 'Reject|Reject'],
          },
        },
      ],
    ),
  );
  final comment = (form['definition']['fields'] as List).firstWhere(
    (f) => f['name'] == 'bpm:comment',
  );
  comment['mandatory'] = requiredComment;
  return form;
}

Map<String, dynamic> documentApprovalTask({
  bool completed = false,
  String outcome = 'Reject',
}) =>
    reviewTask(completed: completed, outcome: outcome)
      ..['name'] = 'scwf:activitiReviewTask'
      ..['properties'] = {
        'bpm_outcomePropertyName': 'scwf:approveRejectOutcome\n\t',
        'scwf_approveRejectOutcome': outcome,
      }
      ..['workflowInstance'] = {'name': 'activiti\$docApproveReject'};

Map<String, dynamic> documentApprovalForm({bool requiredComment = false}) {
  final form = reviewForm(requiredComment: requiredComment);
  final outcome = (form['definition']['fields'] as List).last as Map;
  outcome['name'] = 'scwf:approveRejectOutcome';
  outcome['dataKeyName'] = 'prop_scwf_approveRejectOutcome';
  form['formData']['prop_bpm_outcomePropertyName'] =
      '{http://www.jkl.com/model/workflow/1.0}approveRejectOutcome\n\t';
  return form;
}

WorkflowTaskForm reviewModel({bool requiredComment = false}) =>
    WorkflowTaskForm.fromJson(
      'activiti\$test',
      reviewTask(),
      reviewForm(requiredComment: requiredComment),
    );

class ReviewFake implements WorkflowActionService {
  WorkflowTaskForm current = reviewModel();
  final submitted = <String>[];
  @override
  Future<WorkflowTaskForm> getTaskForm(String id) async => current;
  @override
  Future<void> completeTask(
    WorkflowTaskForm form,
    Map<String, String> values,
    String action,
  ) async {
    submitted.add(action);
  }
}

void main() {
  test(
    'document approval validates its exact custom outcome and trims QName whitespace',
    () {
      final task = documentApprovalTask();
      final raw = documentApprovalForm();
      final model = WorkflowTaskForm.fromJson('custom', task, raw);
      expect(model.unavailableReason, isNull);
      for (final action in ['Approve', 'Reject']) {
        final body = model.submission(model.initialValues, action);
        expect(body['prop_scwf_approveRejectOutcome'], action);
        expect(body.containsKey('prop_wf_reviewOutcome'), isFalse);
      }
      expect(model.actions.last.requiresConfirmation, isTrue);
      task['properties'].remove('bpm_outcomePropertyName');
      expect(
        WorkflowTaskForm.fromJson('custom', task, raw).unavailableReason,
        isNull,
      );
      task['properties']['bpm_outcomePropertyName'] =
          'other:approveRejectOutcome';
      expect(
        WorkflowTaskForm.fromJson('custom', task, raw).unavailableReason,
        isNotNull,
      );
      task['properties']['bpm_outcomePropertyName'] =
          'scwf:approveRejectOutcome';
      (raw['definition']['fields'] as List).last['protectedField'] = true;
      expect(
        WorkflowTaskForm.fromJson('custom', task, raw).unavailableReason,
        isNotNull,
      );
      final mandatory = WorkflowTaskForm.fromJson(
        'custom',
        task,
        documentApprovalForm(requiredComment: true),
      );
      expect(
        () => mandatory.submission(mandatory.initialValues, 'Reject'),
        throwsFormatException,
      );
      task['workflowInstance']['name'] = 'activiti\$signature';
      expect(
        WorkflowTaskForm.fromJson(
          'custom',
          task,
          documentApprovalForm(),
        ).unavailableReason,
        isNotNull,
      );
    },
  );

  for (final name in ['wf:approvedTask', 'wf:rejectedTask']) {
    test('$name acknowledges without sending a review decision', () {
      final task = reviewTask()..['name'] = name;
      final model = WorkflowTaskForm.fromJson(
        'activiti\$test',
        task,
        fixture.formData(),
      );
      expect(model.unavailableReason, isNull);
      expect(model.actions.single.label, 'Acknowledge');
      final payload = model.submission(model.initialValues, 'Next');
      expect(payload['prop_transitions'], 'Next');
      expect(payload.containsKey('prop_wf_reviewOutcome'), isFalse);
    });
  }

  testWidgets('decision buttons keep a gap on desktop and narrow windows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    for (final width in [900.0, 320.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkflowTaskActions(
                key: ValueKey(width),
                service: ReviewFake(),
                taskId: 'layout',
                accountId: 'layout',
                onCompleted: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final approve = tester.getRect(
        find.widgetWithText(FilledButton, 'Approve'),
      );
      final reject = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Reject'),
      );
      expect(approve.overlaps(reject), isFalse);
      if (width > 600) {
        expect(reject.left - approve.right, greaterThanOrEqualTo(12));
      } else {
        expect(reject.top - approve.bottom, greaterThanOrEqualTo(12));
      }
      expect(tester.takeException(), isNull);
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('approve/reject set the outcome and complete through Next', () {
    final form = reviewModel();
    expect(form.unavailableReason, isNull);
    expect(form.actions.map((a) => a.id), ['Approve', 'Reject']);
    expect(form.actions.last.requiresConfirmation, isTrue);
    expect(form.actions.first.requiresConfirmation, isFalse);
    expect(form.fields.any((f) => f.name == 'wf:reviewOutcome'), isFalse);
    for (final action in ['Approve', 'Reject']) {
      final body = form.submission({
        ...form.initialValues,
        'prop_wf_reviewOutcome': 'Bogus',
      }, action);
      expect(body['prop_transitions'], 'Next');
      expect(body['prop_wf_reviewOutcome'], action);
      expect(body['prop_bpm_comment'], '');
    }
    expect(() => form.submission(form.initialValues, 'Next'), throwsStateError);
  });
  test(
    'mandatory comments follow server rules; missing, unknown and protected outcomes block submission',
    () {
      final mandatory = reviewModel(requiredComment: true);
      expect(
        () => mandatory.submission(mandatory.initialValues, 'Reject'),
        throwsFormatException,
      );
      final raw = reviewForm();
      final outcome = (raw['definition']['fields'] as List).last as Map;
      outcome['protectedField'] = true;
      expect(
        WorkflowTaskForm.fromJson('id', reviewTask(), raw).unavailableReason,
        isNotNull,
      );
      outcome['protectedField'] = false;
      outcome['constraints'][0]['parameters']['allowedValues'] = ['Sign|Sign'];
      expect(
        WorkflowTaskForm.fromJson('id', reviewTask(), raw).unavailableReason,
        isNotNull,
      );
      final signature = reviewTask()..['name'] = 'scwf:activitiReviewTask';
      expect(
        WorkflowTaskForm.fromJson(
          'id',
          signature,
          reviewForm(),
        ).unavailableReason,
        isNotNull,
      );
      final wrongProperty =
          reviewTask()
            ..['properties'] = {'bpm_outcomePropertyName': 'custom:signature'};
      expect(
        WorkflowTaskForm.fromJson(
          'id',
          wrongProperty,
          reviewForm(),
        ).unavailableReason,
        isNotNull,
      );
    },
  );
  test('hidden transitions and missing outcome metadata block review', () {
    final hidden = reviewTask();
    hidden['definition']['node']['transitions'][0]['isHidden'] = true;
    expect(
      WorkflowTaskForm.fromJson('id', hidden, reviewForm()).unavailableReason,
      isNotNull,
    );
    expect(
      WorkflowTaskForm.fromJson(
        'id',
        reviewTask(),
        fixture.formData(),
      ).unavailableReason,
      isNotNull,
    );
  });
  for (final custom in [false, true]) {
    for (final action in ['Approve', 'Reject']) {
      test(
        '${custom ? 'document approval' : 'standard review'} $action posts its outcome and verifies server result',
        () async {
          var completed = false, mutations = 0;
          final service = AlfrescoWorkflowService(
            baseUrl: 'https://server/alfresco',
            authToken: 'ticket',
            client: MockClient((request) async {
              if (request.url.path.endsWith('/formprocessor')) {
                mutations++;
                final body = jsonDecode(request.body);
                expect(body['prop_transitions'], 'Next');
                expect(
                  body[custom
                      ? 'prop_scwf_approveRejectOutcome'
                      : 'prop_wf_reviewOutcome'],
                  action,
                );
                completed = true;
                return http.Response('{}', 200);
              }
              if (request.url.path.endsWith('/formdefinitions')) {
                final raw = jsonEncode({
                  'data': custom ? documentApprovalForm() : reviewForm(),
                });
                return http.Response(
                  custom ? raw.replaceAll(r'\n\t', '\n\t') : raw,
                  200,
                );
              }
              if (request.url.path.endsWith('/task-instances')) {
                return http.Response(
                  jsonEncode({
                    'data': [custom ? documentApprovalTask() : reviewTask()],
                    'paging': {'totalItems': 1},
                  }),
                  200,
                );
              }
              return http.Response(
                jsonEncode({
                  'data': (custom ? documentApprovalTask : reviewTask)(
                    completed: completed,
                    outcome: completed ? action : 'Reject',
                  ),
                }),
                200,
              );
            }),
          );
          final form = await service.getTaskForm('activiti\$test');
          await service.completeTask(form, form.initialValues, action);
          expect(mutations, 1);
        },
      );
    }
  }
  test(
    'wrong recorded outcome is not reported as success or retried',
    () async {
      var completed = false, mutations = 0;
      final service = AlfrescoWorkflowService(
        baseUrl: 'https://server/alfresco',
        authToken: 'ticket',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/formprocessor')) {
            mutations++;
            completed = true;
            return http.Response('{}', 200);
          }
          if (request.url.path.endsWith('/formdefinitions')) {
            return http.Response(jsonEncode({'data': reviewForm()}), 200);
          }
          if (request.url.path.endsWith('/task-instances')) {
            return http.Response(
              jsonEncode({
                'data': [reviewTask()],
                'paging': {'totalItems': 1},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': reviewTask(completed: completed, outcome: 'Reject'),
            }),
            200,
          );
        }),
      );
      final form = await service.getTaskForm('activiti\$test');
      await expectLater(
        service.completeTask(form, form.initialValues, 'Approve'),
        throwsA(predicate((e) => e.toString().contains('Unable to confirm'))),
      );
      expect(mutations, 1);
    },
  );
  testWidgets(
    'rejection cancellation makes no request; confirmation submits with optional empty comment',
    (tester) async {
      final service = ReviewFake();
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
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.text('Reject task?'), findsOneWidget);
      expect(service.submitted, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.submitted, isEmpty);
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Reject'),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.submitted, ['Reject']);
    },
  );
  testWidgets('approval submits directly without a confirmation', (
    tester,
  ) async {
    final service = ReviewFake();
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
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.submitted, ['Approve']);
  });
}
