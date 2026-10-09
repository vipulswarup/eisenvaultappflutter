import 'workflow_task_actions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/workflow_task.dart';
import '../../services/workflows/alfresco_workflow_service.dart';

class MyTasksScreen extends StatefulWidget {
  final WorkflowService service;
  final String accountLabel;
  final String? accountId;
  const MyTasksScreen({
    super.key,
    required this.service,
    required this.accountLabel,
    this.accountId,
  });
  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  late Future<List<WorkflowTask>> _tasks;
  @override
  void initState() {
    super.initState();
    _tasks = widget.service.getMyTasks();
  }

  Future<void> _refresh() async {
    final future = widget.service.getMyTasks();
    setState(() {
      _tasks = future;
    });
    try {
      await future;
    } catch (_) {
      /* FutureBuilder displays the error. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My Tasks'),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Refresh tasks',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(widget.accountLabel),
        ),
        Expanded(
          child: FutureBuilder<List<WorkflowTask>>(
            future: _tasks,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErrorView(error: snapshot.error!, retry: _refresh);
              }
              final tasks = snapshot.data!;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children:
                      tasks.isEmpty
                          ? [
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No active tasks',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ]
                          : [
                            for (final task in tasks)
                              ListTile(
                                leading: Icon(
                                  task.isPooled
                                      ? Icons.group_outlined
                                      : Icons.assignment_outlined,
                                ),
                                title: Text(task.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (task.workflowType.isNotEmpty)
                                      Text(task.workflowType),
                                    if (task.summary.isNotEmpty &&
                                        task.summary != task.title)
                                      Text(task.summary),
                                    _DueDate(task: task),
                                    if (task.isPooled)
                                      const Text(
                                        'Available through your groups',
                                      ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => WorkflowTaskScreen(
                                            service: widget.service,
                                            taskId: task.id,
                                            accountId: widget.accountId,
                                          ),
                                    ),
                                  );
                                  if (mounted) await _refresh();
                                },
                              ),
                          ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class WorkflowTaskScreen extends StatefulWidget {
  final WorkflowService service;
  final String taskId;
  final String? accountId;
  const WorkflowTaskScreen({
    super.key,
    required this.service,
    required this.taskId,
    this.accountId,
  });
  @override
  State<WorkflowTaskScreen> createState() => _WorkflowTaskScreenState();
}

class _WorkflowTaskScreenState extends State<WorkflowTaskScreen> {
  late Future<WorkflowTask?> _task;
  Future<List<String>>? _documents;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _documents = null;
    _task = widget.service.getTask(widget.taskId).then((task) {
      if (task != null && task.isActive) {
        _documents = widget.service.getDocumentNames(task);
      }
      return task;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Task details'),
      actions: [
        IconButton(
          tooltip: 'Refresh task',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(_load),
        ),
      ],
    ),
    body: FutureBuilder<WorkflowTask?>(
      future: _task,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorView(
            error: snapshot.error!,
            retry: () => setState(_load),
          );
        }
        final task = snapshot.data;
        if (task == null || !task.isActive) {
          return const Center(
            child: Text(
              'This task is no longer available. It may have been completed or reassigned.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (task.workflowType.isNotEmpty)
              _field('Workflow', task.workflowType),
            if (task.initiator.isNotEmpty) _field('Initiator', task.initiator),
            if (task.summary.isNotEmpty) _field('Description', task.summary),
            _DueDate(task: task),
            const SizedBox(height: 16),
            _field(
              'Assignment',
              task.isPooled
                  ? 'Available through your groups'
                  : 'Assigned to you',
            ),
            _field(
              'Current comments',
              task.comments.isEmpty ? 'No current comments' : task.comments,
            ),
            FutureBuilder<List<String>>(
              future: _documents,
              builder: (context, docs) {
                if (docs.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (docs.hasError) {
                  return const Text(
                    'Unable to load document names. Refresh to try again.',
                  );
                }
                return _field(
                  'Documents',
                  docs.data!.isEmpty
                      ? 'No documents supplied'
                      : docs.data!.join('\n'),
                );
              },
            ),
            const SizedBox(height: 24),
            if (widget.service is WorkflowActionService &&
                widget.accountId != null)
              WorkflowTaskActions(
                key: ValueKey(_task),
                service: widget.service as WorkflowActionService,
                taskId: task.id,
                accountId: widget.accountId!,
                onCompleted: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task completed')),
                  );
                  Navigator.of(context).pop();
                },
              )
            else
              const Text('Task actions are not available in this version.'),
          ],
        );
      },
    ),
  );
  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    ),
  );
}

class _DueDate extends StatelessWidget {
  final WorkflowTask task;
  const _DueDate({required this.task});
  @override
  Widget build(BuildContext context) {
    final status = task.dueStatus(DateTime.now());
    final color =
        status == 'Overdue'
            ? Colors.red.shade700
            : status == 'Due within 24 hours'
            ? Colors.amber.shade900
            : null;
    final date =
        task.dueDate == null
            ? ''
            : ' · ${DateFormat.yMMMd().add_jm().format(task.dueDate!.toLocal())}';
    return Text('$status$date', style: TextStyle(color: color));
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const _ErrorView({required this.error, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Unable to load tasks. Check your connection and try again.',
          ),
          const SizedBox(height: 8),
          Text(error.toString().replaceFirst('Exception: ', '')),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
