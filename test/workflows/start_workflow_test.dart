import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eisenvaultappflutter/models/workflow_start_form.dart';
import 'package:eisenvaultappflutter/screens/workflows/start_workflow_screen.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'package:eisenvaultappflutter/services/workflows/workflow_draft_store.dart';
import 'task_form_test.dart' as fixture;

const definition = WorkflowDefinition(
  'activiti\$activitiReview:1:8',
  'activiti\$activitiReview',
  'Review',
);
Map<String, dynamic> startNode() => {
  'id': 'doc',
  'name': 'contract.pdf',
  'isFile': true,
  'permissions': {
    'locallySet': [
      {
        'authorityId': 'reviewer',
        'name': 'Consumer',
        'accessStatus': 'ALLOWED',
      },
    ],
  },
};
Map<String, dynamic> startMetadata() => {
  'definition': {
    'fields': [
      {
        'name': 'bpm:assignee',
        'dataKeyName': 'assoc_bpm_assignee',
        'type': 'association',
        'endpointType': 'cm:person',
        'endpointMany': false,
      },
      {
        'name': 'packageItems',
        'dataKeyName': 'assoc_packageItems',
        'type': 'association',
      },
      fixture.field('bpm:workflowDescription', 'text', required: false),
      fixture.field('bpm:workflowPriority', 'int', required: false),
      fixture.field('bpm:workflowDueDate', 'date', required: false),
    ],
  },
  'formData': {'prop_bpm_workflowPriority': 2},
};
WorkflowStartForm startForm() =>
    WorkflowStartForm.fromJson(definition, startNode(), startMetadata());
const reviewer = WorkflowAssignee(
  'reviewer',
  'Reviewer',
  'workspace://SpacesStore/person',
);

class StartFake implements WorkflowStartService {
  int starts = 0;
  bool uncertain = false;
  @override
  Future<List<WorkflowDefinition>> getStartDefinitions() async => [definition];
  @override
  Future<WorkflowStartForm> getStartForm(
    WorkflowDefinition d,
    String n,
  ) async => startForm();
  @override
  Future<List<WorkflowAssignee>> searchAssignees(String n, String q) async => [
    reviewer,
  ];
  @override
  Future<String> startWorkflow(
    WorkflowStartForm f,
    Map<String, String> v,
    WorkflowAssignee a,
  ) async {
    starts++;
    if (uncertain) throw Exception('Connection lost');
    return 'activiti\$created';
  }
}

void main() {
  test(
    'single document, typed defaults, UTC due date and no injected package',
    () {
      final form = startForm();
      final values = {
        ...form.initialValues,
        'prop_bpm_workflowDueDate': '2026-10-12T12:00:00+05:30',
        'assoc_packageItems_added': 'other',
      };
      final body = form.submission(values, reviewer);
      expect(body['assoc_packageItems_added'], 'workspace://SpacesStore/doc');
      expect(body['assoc_bpm_assignee_added'], reviewer.nodeRef);
      expect(body['prop_bpm_workflowPriority'], 2);
      expect(body['prop_bpm_workflowDueDate'], '2026-10-12T06:30:00.000Z');
    },
  );
  test('unsupported mandatory controls and non-documents block starts', () {
    final raw = startMetadata();
    (raw['definition']['fields'] as List).add(
      fixture.field('custom:required', 'boolean'),
    );
    expect(
      WorkflowStartForm.fromJson(
        definition,
        startNode(),
        raw,
      ).unavailableReason,
      isNotNull,
    );
    expect(
      WorkflowStartForm.fromJson(definition, {
        ...startNode(),
        'isFile': false,
      }, startMetadata()).unavailableReason,
      isNotNull,
    );
  });
  test(
    'ACL handles inherited groups, explicit denies and unsupported grants',
    () {
      expect(hasDocumentReadAccess(startNode(), {'reviewer'}), isTrue);
      final node = {
        'permissions': {
          'inherited': [
            {
              'authorityId': 'GROUP_review',
              'name': 'Consumer',
              'accessStatus': 'ALLOWED',
            },
          ],
        },
      };
      expect(hasDocumentReadAccess(node, {'GROUP_review'}), isTrue);
      expect(hasDocumentReadAccess(node, {'other'}), isFalse);
      (node['permissions'] as Map)['locallySet'] = [
        {'authorityId': 'reviewer', 'name': 'Read', 'accessStatus': 'DENIED'},
      ];
      expect(
        hasDocumentReadAccess(node, {'GROUP_review', 'reviewer'}),
        isFalse,
      );
    },
  );
  test(
    'server start revalidates assignee and confirms exactly one packaged document',
    () async {
      var posts = 0;
      final service = AlfrescoWorkflowService(
        baseUrl: 'https://server/alfresco',
        authToken: 'ticket',
        client: MockClient((r) async {
          Object response;
          if (r.url.path.endsWith('workflow-definitions')) {
            response = {
              'data': [
                {
                  'id': definition.id,
                  'name': definition.name,
                  'title': definition.title,
                },
              ],
            };
          } else if (r.url.path.endsWith('formdefinitions')) {
            response = {'data': startMetadata()};
          } else if (r.url.path.endsWith('/nodes/doc')) {
            response = {'entry': startNode()};
          } else if (r.url.path.endsWith('/people/-me-')) {
            response = {
              'entry': {'id': 'initiator'},
            };
          } else if (r.url.path.endsWith('/people/reviewer')) {
            response = {'userName': 'reviewer', 'enabled': true};
          } else if (r.url.path.endsWith('/groups')) {
            response = {
              'list': {
                'entries': [],
                'pagination': {'hasMoreItems': false},
              },
            };
          } else if (r.url.path.endsWith('/search')) {
            response = {
              'list': {
                'entries': [
                  {
                    'entry': {'id': 'person'},
                  },
                ],
              },
            };
          } else if (r.url.path.endsWith('/formprocessor')) {
            posts++;
            expect(
              jsonDecode(r.body)['assoc_packageItems_added'],
              'workspace://SpacesStore/doc',
            );
            response = {
              'persistedObject':
                  'WorkflowInstance[id=activiti\$created,active=true]',
            };
          } else if (r.url.path.endsWith('/children')) {
            response = {
              'list': {
                'entries': [
                  {
                    'entry': {'id': 'doc'},
                  },
                ],
                'pagination': {'hasMoreItems': false},
              },
            };
          } else {
            response = {
              'data': {'package': 'workspace://SpacesStore/package'},
            };
          }
          return http.Response(jsonEncode(response), 200);
        }),
      );
      expect(
        await service.startWorkflow(
          startForm(),
          startForm().initialValues,
          reviewer,
        ),
        'activiti\$created',
      );
      expect(posts, 1);
    },
  );
  test(
    'direct ACL grants remain verifiable when group membership is private',
    () async {
      final service = AlfrescoWorkflowService(
        baseUrl: 'https://server/alfresco',
        authToken: 'ticket',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/groups')) return http.Response('{}', 403);
          Object response;
          if (r.url.path.endsWith('/nodes/doc')) {
            response = {'entry': startNode()};
          } else if (r.url.path.endsWith('/people/-me-')) {
            response = {
              'entry': {'id': 'initiator'},
            };
          } else if (r.url.path.endsWith('/people')) {
            response = {
              'people': [
                {
                  'userName': 'reviewer',
                  'enabled': true,
                  'firstName': 'Reviewer',
                },
                {'userName': 'unrelated', 'enabled': true},
              ],
            };
          } else {
            response = {
              'list': {
                'entries': [
                  {
                    'entry': {'id': 'person'},
                  },
                ],
              },
            };
          }
          return http.Response(jsonEncode(response), 200);
        }),
      );
      final people = await service.searchAssignees('doc', 'review');
      expect(people.map((p) => p.username), ['reviewer']);
      final node = startNode();
      (node['permissions']['locallySet'] as List).add({
        'authorityId': 'GROUP_unknown',
        'name': 'Read',
        'accessStatus': 'DENIED',
      });
      expect(
        hasDocumentReadAccess(node, {'reviewer'}, membershipsKnown: false),
        isFalse,
      );
    },
  );
  test(
    'permission-request definitions are excluded from workflow selection',
    () async {
      final service = AlfrescoWorkflowService(
        baseUrl: 'https://server/alfresco',
        authToken: 'ticket',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {
                  'id': definition.id,
                  'name': definition.name,
                  'title': definition.title,
                },
                {
                  'id': 'excluded',
                  'name': 'activiti\$activitiPermissionProcess',
                  'title': 'Permission',
                },
              ],
            }),
            200,
          ),
        ),
      );
      expect((await service.getStartDefinitions()).map((d) => d.name), [
        definition.name,
      ]);
    },
  );
  testWidgets('uncertain start locks saved attempt across reopening', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = StartFake()..uncertain = true;
    Widget screen() => MaterialApp(
      home: StartWorkflowScreen(
        service: service,
        nodeId: 'doc',
        documentName: 'contract.pdf',
        accountId: 'a',
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search users with document access'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search users'),
      'review',
    );
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reviewer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Start workflow'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start workflow'));
    await tester.pumpAndSettle();
    expect(service.starts, 1);
    expect(
      (await WorkflowDraftStore(
        'a',
        'start:doc:${definition.id}',
      ).read())!['values']['startAttemptPending'],
      'true',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start workflow'),
          )
          .onPressed,
      isNull,
    );
    expect(service.starts, 1);
  });
}
