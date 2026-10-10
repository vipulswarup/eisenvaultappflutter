/// Provider-independent envelope. Never contains credentials or document content.
class WorkflowNotification {
  final String eventId, accountId, taskId;

  const WorkflowNotification({
    required this.eventId,
    required this.accountId,
    required this.taskId,
  });

  factory WorkflowNotification.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty || value.length > 512) {
        throw FormatException('Invalid notification $key');
      }
      return value;
    }

    if (json['type'] != 'workflow.task.assigned' || json['version'] != 1) {
      throw const FormatException('Unsupported workflow notification');
    }
    return WorkflowNotification(
      eventId: requiredString('eventId'),
      accountId: requiredString('accountId'),
      taskId: requiredString('taskId'),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'type': 'workflow.task.assigned',
    'eventId': eventId,
    'accountId': accountId,
    'taskId': taskId,
  };
}
