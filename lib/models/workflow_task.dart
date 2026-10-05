/// A current task from Alfresco's built-in workflow engine.
class WorkflowTask {
  final String id, title, workflowType, initiator, comments, state;
  final DateTime? dueDate;
  final String? packageNode;
  final bool isPooled;

  const WorkflowTask({
    required this.id,
    required this.title,
    this.workflowType = '',
    this.initiator = '',
    this.comments = '',
    this.state = 'IN_PROGRESS',
    this.dueDate,
    this.packageNode,
    this.isPooled = false,
  });

  factory WorkflowTask.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map? ?? {};
    final workflow = json['workflowInstance'] as Map? ?? {};
    final person = workflow['initiator'] as Map? ?? {};
    final name = [
      person['firstName'],
      person['lastName'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Missing task ID');
    }
    return WorkflowTask(
      id: id,
      title:
          (json['title'] ?? json['description'] ?? 'Workflow task').toString(),
      workflowType: (workflow['title'] ?? workflow['name'] ?? '').toString(),
      initiator: name.isNotEmpty ? name : (person['userName'] ?? '').toString(),
      comments:
          (properties['bpm_comment'] ?? properties['bpm:comment'] ?? '')
              .toString(),
      dueDate: DateTime.tryParse(
        (properties['bpm_dueDate'] ?? properties['bpm:dueDate'] ?? '')
            .toString(),
      ),
      state: (json['state'] ?? '').toString(),
      packageNode: workflow['package'] as String?,
      isPooled: json['isPooled'] == true,
    );
  }

  bool get isActive => state.toUpperCase() == 'IN_PROGRESS';

  String dueStatus(DateTime now) {
    final due = dueDate;
    if (due == null) return 'No due date';
    if (due.isBefore(now)) return 'Overdue';
    if (due.difference(now) <= const Duration(hours: 24)) {
      return 'Due within 24 hours';
    }
    return 'Upcoming';
  }

  static int compare(WorkflowTask a, WorkflowTask b) {
    if (a.dueDate == null && b.dueDate != null) return 1;
    if (b.dueDate == null && a.dueDate != null) return -1;
    final dates = a.dueDate?.compareTo(b.dueDate!) ?? 0;
    return dates != 0 ? dates : a.id.compareTo(b.id);
  }
}
