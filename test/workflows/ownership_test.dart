import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:eisenvaultappflutter/models/workflow_task.dart';
import 'package:eisenvaultappflutter/models/workflow_task_form.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'review_actions_test.dart' as fixture;

Map<String, dynamic> pooled({String? owner}) =>
    fixture.reviewTask()
      ..['id'] = 'activiti\$123'
      ..['workflowInstance'] = {'name': 'activiti\$activitiReviewPooled'}
      ..['isPooled'] = true
      ..['owner'] = owner == null ? null : {'userName': owner}
      ..['isClaimable'] = owner == null
      ..['isReleasable'] = owner == 'me';

void main() {
  test(
    'pooled review actions unlock after claim despite isPooled remaining true',
    () {
      expect(
        WorkflowTaskForm.fromJson(
          'activiti\$123',
          pooled(),
          fixture.reviewForm(),
        ).unavailableReason,
        isNotNull,
      );
      final form = WorkflowTaskForm.fromJson(
        'activiti\$123',
        pooled(owner: 'me'),
        fixture.reviewForm(),
      );
      expect(form.unavailableReason, isNull);
      expect(form.actions.map((a) => a.id), ['Approve', 'Reject']);
    },
  );
  for (final claim in [true, false]) {
    test(
      '${claim ? 'claim' : 'release'} changes only state and verifies owner',
      () async {
        var row = pooled(owner: claim ? null : 'me');
        var writes = 0;
        final service = AlfrescoWorkflowService(
          baseUrl: 'https://server/alfresco',
          authToken: 'ticket',
          client: MockClient((r) async {
            if (r.method == 'PUT') {
              writes++;
              expect(
                r.url.path,
                endsWith('/public/workflow/versions/1/tasks/123'),
              );
              expect(r.url.queryParameters['select'], 'state');
              expect(jsonDecode(r.body), {
                'state': claim ? 'claimed' : 'unclaimed',
              });
              row = pooled(owner: claim ? 'me' : null);
              return http.Response('{}', 200);
            }
            if (r.url.path.endsWith('/people/-me-')) {
              return http.Response('{"entry":{"id":"me"}}', 200);
            }
            if (r.url.path.endsWith('/task-instances')) {
              return http.Response(
                jsonEncode({
                  'data': [row],
                  'paging': {'totalItems': 1},
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'data': row}), 200);
          }),
        );
        await service.changeOwnership(WorkflowTask.fromJson(row), claim: claim);
        expect(writes, 1);
      },
    );
  }
  for (final mode in ['stale', 'conflict', 'uncertain', 'wrongOwner']) {
    test('$mode ownership response never retries the mutation', () async {
      var row = pooled();
      final snapshot = WorkflowTask.fromJson(row);
      if (mode == 'stale') row = pooled(owner: 'other');
      var writes = 0;
      final service = AlfrescoWorkflowService(
        baseUrl: 'https://server/alfresco',
        authToken: 'ticket',
        client: MockClient((r) async {
          if (r.method == 'PUT') {
            writes++;
            if (mode == 'conflict') return http.Response('{}', 409);
            if (mode == 'uncertain') {
              throw http.ClientException('connection lost');
            }
            row = pooled(owner: 'other');
            return http.Response('{}', 200);
          }
          if (r.url.path.endsWith('/people/-me-')) {
            return http.Response('{"entry":{"id":"me"}}', 200);
          }
          if (r.url.path.endsWith('/task-instances')) {
            return http.Response(
              jsonEncode({
                'data': [row],
                'paging': {'totalItems': 1},
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'data': row}), 200);
        }),
      );
      await expectLater(
        service.changeOwnership(snapshot, claim: true),
        throwsException,
      );
      expect(writes, mode == 'stale' ? 0 : 1);
    });
  }
}
