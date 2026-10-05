import 'dart:convert';
import 'package:eisenvaultappflutter/models/workflow_task.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';
import 'package:eisenvaultappflutter/screens/workflows/my_tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> taskJson(String id, {String state = 'IN_PROGRESS'}) => {
  'id': id,
  'title': 'Review contract',
  'state': state,
  'isPooled': true,
  'properties': {
    'bpm_dueDate': '2026-10-01T10:00:00+05:30',
    'bpm_comment': 'Please review',
  },
  'workflowInstance': {
    'title': 'Review and approve',
    'package': 'workspace://SpacesStore/package-id',
    'initiator': {'firstName': 'Test', 'lastName': 'User'},
  },
};

class FakeService implements WorkflowService {
  List<WorkflowTask> tasks;
  bool fail = false;
  FakeService(this.tasks);
  @override
  Future<List<WorkflowTask>> getMyTasks() async {
    if (fail) throw Exception('Offline');
    return tasks;
  }

  @override
  Future<WorkflowTask?> getTask(String id) async =>
      tasks.where((t) => t.id == id).firstOrNull;
  @override
  Future<List<String>> getDocumentNames(WorkflowTask task) async => [
    'contract.pdf',
  ];
}

void main() {
  test(
    'parses task metadata and timezone; due boundaries and null ordering',
    () {
      final task = WorkflowTask.fromJson(taskJson('1'));
      expect(task.initiator, 'Test User');
      expect(task.comments, 'Please review');
      expect(task.isPooled, isTrue);
      expect(task.dueDate, DateTime.utc(2026, 10, 1, 4, 30));
      expect(
        task.dueStatus(task.dueDate!.add(const Duration(seconds: 1))),
        'Overdue',
      );
      expect(
        task.dueStatus(task.dueDate!.subtract(const Duration(hours: 24))),
        'Due within 24 hours',
      );
      expect(
        task.dueStatus(task.dueDate!.subtract(const Duration(hours: 25))),
        'Upcoming',
      );
      final items = [
        const WorkflowTask(id: 'z', title: 'No date'),
        task,
        WorkflowTask(
          id: 'early',
          title: 'Earlier',
          dueDate: DateTime.utc(2026, 9, 1),
        ),
      ];
      items.sort(WorkflowTask.compare);
      expect(items.map((t) => t.id), ['early', '1', 'z']);
    },
  );

  test(
    'authenticated account-local paging includes pooled tasks, removes completed and duplicates',
    () async {
      final requests = <http.Request>[];
      final service = AlfrescoWorkflowService(
        baseUrl: 'https://server/alfresco/',
        authToken: 'Basic ticket',
        client: MockClient((request) async {
          requests.add(request);
          final second = request.url.queryParameters['skipCount'] == '2';
          return http.Response(
            jsonEncode({
              'data':
                  second
                      ? [taskJson('1'), taskJson('2')]
                      : [taskJson('1'), taskJson('old', state: 'COMPLETED')],
              'paging': {'totalItems': 4},
            }),
            200,
          );
        }),
      );
      expect((await service.getMyTasks()).map((t) => t.id), ['1', '2']);
      expect(requests, hasLength(2));
      expect(requests.first.url.path, '/alfresco/s/api/task-instances');
      expect(requests.first.url.queryParameters['pooledTasks'], 'true');
      expect(requests.first.url.queryParameters['authority'], isNull);
      expect(requests.first.headers['authorization'], 'Basic ticket');
    },
  );

  test(
    'details reject a readable task reassigned to another account',
    () async {
      final service = AlfrescoWorkflowService(
        baseUrl: 'https://server/alfresco',
        authToken: 'token',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/task-instances/1')
                  ? {'data': taskJson('1')}
                  : {
                    'data': [],
                    'paging': {'totalItems': 0},
                  },
            ),
            200,
          ),
        ),
      );
      expect(await service.getTask('1'), isNull);
    },
  );

  test('details handle missing tasks and session expiry', () async {
    final missing = AlfrescoWorkflowService(
      baseUrl: 'https://server/alfresco',
      authToken: 'token',
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect(await missing.getTask('missing'), isNull);
    final expired = AlfrescoWorkflowService(
      baseUrl: 'https://server/alfresco',
      authToken: 'token',
      client: MockClient((_) async => http.Response('', 401)),
    );
    await expectLater(
      expired.getMyTasks(),
      throwsA(predicate((e) => e.toString().contains('sign in again'))),
    );
  });

  test('document names resolve the workflow package with pagination', () async {
    final service = AlfrescoWorkflowService(
      baseUrl: 'https://server/alfresco',
      authToken: 'token',
      client: MockClient((request) async {
        expect(
          request.url.path,
          '/alfresco/api/-default-/public/alfresco/versions/1/nodes/package-id/children',
        );
        return http.Response(
          jsonEncode({
            'list': {
              'entries': [
                {
                  'entry': {'name': 'contract.pdf', 'isFile': true},
                },
              ],
              'pagination': {'hasMoreItems': false},
            },
          }),
          200,
        );
      }),
    );
    expect(
      await service.getDocumentNames(WorkflowTask.fromJson(taskJson('1'))),
      ['contract.pdf'],
    );
  });

  testWidgets('lists tasks and opens refreshed details with document names', (
    tester,
  ) async {
    final service = FakeService([WorkflowTask.fromJson(taskJson('1'))]);
    await tester.pumpWidget(
      MaterialApp(
        home: MyTasksScreen(service: service, accountLabel: 'user · server'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('user · server'), findsOneWidget);
    expect(find.text('Available through your groups'), findsOneWidget);
    await tester.tap(find.text('Review contract'));
    await tester.pumpAndSettle();
    expect(find.text('Task details'), findsOneWidget);
    expect(find.text('contract.pdf'), findsOneWidget);
    expect(find.text('Please review'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
  });

  testWidgets('empty list, network error and retry', (tester) async {
    final service = FakeService([])..fail = true;
    await tester.pumpWidget(
      MaterialApp(home: MyTasksScreen(service: service, accountLabel: 'user')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No active tasks'), findsOneWidget);
  });

  testWidgets('unavailable task does not display old details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkflowTaskScreen(service: FakeService([]), taskId: 'gone'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(find.text('Documents'), findsNothing);
  });
}
