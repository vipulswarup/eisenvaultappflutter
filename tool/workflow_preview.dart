// Emulator-only preview: flutter run -t tool/workflow_preview.dart -d <device>
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/models/workflow_task.dart';
import 'package:eisenvaultappflutter/screens/workflows/my_tasks_screen.dart';
import 'package:eisenvaultappflutter/services/workflows/alfresco_workflow_service.dart';

void main() => runApp(
  MaterialApp(
    home: MyTasksScreen(
      service: _PreviewService(),
      accountLabel: 'Preview data · No server connection',
    ),
  ),
);

class _PreviewService implements WorkflowService {
  final tasks = [
    WorkflowTask(
      id: 'overdue',
      title: 'Review supplier contract',
      workflowType: 'Review and approve',
      initiator: 'Alex Smith',
      comments: 'Please review the updated terms.',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
    ),
    WorkflowTask(
      id: 'group',
      title: 'Review purchase request',
      workflowType: 'Pooled review',
      isPooled: true,
      initiator: 'Jamie Lee',
      dueDate: DateTime.now().add(const Duration(hours: 12)),
    ),
    const WorkflowTask(
      id: 'undated',
      title: 'Check policy document',
      workflowType: 'Ad hoc task',
    ),
  ];
  @override
  Future<List<WorkflowTask>> getMyTasks() async =>
      [...tasks]..sort(WorkflowTask.compare);
  @override
  Future<WorkflowTask?> getTask(String id) async =>
      tasks.where((task) => task.id == id).firstOrNull;
  @override
  Future<List<String>> getDocumentNames(WorkflowTask task) async => [
    '${task.id}.pdf',
  ];
}
