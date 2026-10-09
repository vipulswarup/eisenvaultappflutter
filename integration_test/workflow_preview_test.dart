import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/models/workflow_task.dart';
import 'package:eisenvaultappflutter/screens/workflows/my_tasks_screen.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';

class PreviewFixture implements WorkflowService, WorkflowDocumentService {
  @override
  final String baseUrl;
  @override
  String get authToken => 'Basic fixture';
  PreviewFixture(this.baseUrl);
  static const task = WorkflowTask(
    id: 'fixture',
    title: 'Workflow preview test',
  );
  @override
  Future<List<WorkflowTask>> getMyTasks() async => [task];
  @override
  Future<WorkflowTask?> getTask(String id) async => task;
  @override
  Future<List<String>> getDocumentNames(WorkflowTask task) async => [
    'review.txt',
  ];
  @override
  Future<List<BrowseItem>> getDocuments(WorkflowTask task) async => [
    const BrowseItem(id: 'text-node', name: 'review.txt', type: 'file'),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('workflow document preview Back returns to the same workflow', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      expect(
        request.uri.path,
        '/alfresco/api/-default-/public/alfresco/versions/1/nodes/text-node/content',
      );
      expect(request.headers.value('Authorization'), 'Basic fixture');
      requests++;
      request.response.write('Document opened from workflow');
      await request.response.close();
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkflowTaskScreen(
            service: PreviewFixture('http://127.0.0.1:${server.port}/alfresco'),
            taskId: 'fixture',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('review.txt'));
      await tester.tap(find.text('review.txt'));
      for (
        var i = 0;
        i < 20 && find.text('Document opened from workflow').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Document opened from workflow'), findsOneWidget);
      expect(requests, 1);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Task details'), findsOneWidget);
      expect(find.text('Workflow preview test'), findsOneWidget);
      expect(find.text('review.txt'), findsOneWidget);
    } finally {
      await server.close(force: true);
    }
  });
}
