import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class WorkflowFormField {
  final Map<String, dynamic> metadata;
  WorkflowFormField(this.metadata);
  String get name => metadata['name'] as String;
  String get key => metadata['dataKeyName'] as String;
  String get label => (metadata['label'] ?? name).toString();
  String get dataType => (metadata['dataType'] ?? '').toString();
  bool get protected => metadata['protectedField'] == true;
  bool get required =>
      metadata['mandatory'] == true || metadata['endpointMandatory'] == true;
  List<Map> get constraints =>
      (metadata['constraints'] as List? ?? []).cast<Map>();
  Map<String, String> get choices {
    final result = <String, String>{};
    for (final constraint in constraints) {
      if (constraint['type'] == 'LIST') {
        for (final raw in constraint['parameters']['allowedValues'] as List) {
          final parts = raw.toString().split('|');
          result[parts.first] =
              parts.length > 1 ? parts.skip(1).join('|') : parts.first;
        }
      }
    }
    return result;
  }

  bool get supported =>
      metadata['type'] == 'property' &&
      metadata['repeating'] != true &&
      ['text', 'int'].contains(dataType) &&
      constraints.every(
        (c) => ['LIST', 'LENGTH', 'MINMAX'].contains(c['type']),
      );

  String? validate(String value) {
    if (required && value.trim().isEmpty) return '$label is required';
    if (value.isEmpty) return null;
    if (dataType == 'int' && int.tryParse(value) == null) {
      return 'Enter a whole number';
    }
    if (choices.isNotEmpty && !choices.containsKey(value)) {
      return 'Select an allowed value';
    }
    for (final constraint in constraints) {
      final params = constraint['parameters'] as Map;
      if (constraint['type'] == 'LENGTH') {
        if (value.length < (params['minLength'] as num? ?? 0) ||
            value.length > (params['maxLength'] as num? ?? double.infinity)) {
          return 'Invalid length for $label';
        }
      }
      if (constraint['type'] == 'MINMAX') {
        final number = num.tryParse(value);
        if (number == null ||
            number < (params['minValue'] as num? ?? double.negativeInfinity) ||
            number > (params['maxValue'] as num? ?? double.infinity)) {
          return '$label is outside the allowed range';
        }
      }
    }
    return null;
  }

  Object value(String text) => dataType == 'int' ? int.parse(text) : text;
}

class WorkflowTaskAction {
  final String id, label, transitionId;
  final Map<String, String> properties;
  final bool requiresConfirmation;
  const WorkflowTaskAction({
    required this.id,
    required this.label,
    required this.transitionId,
    this.properties = const {},
    this.requiresConfirmation = false,
  });
}

/// A deliberately limited, fail-closed standard task form.
class WorkflowTaskForm {
  final String taskId, fingerprint;
  final List<WorkflowFormField> fields;
  final Map<String, dynamic> data;
  final Map<String, String> transitions;
  final String? unavailableReason;
  final List<WorkflowTaskAction> actions;
  WorkflowTaskForm._(
    this.taskId,
    this.fingerprint,
    this.fields,
    this.data,
    this.transitions,
    this.unavailableReason,
    this.actions,
  );

  static bool supportsTask(Map<String, dynamic> task) {
    final workflow = (task['workflowInstance'] as Map?)?['name'];
    return (workflow == 'activiti\$docApproveReject' &&
            task['name'] == 'scwf:activitiReviewTask') ||
        (workflow == 'activiti\$activitiAdhoc' &&
            ['wf:adhocTask', 'wf:completedAdhocTask'].contains(task['name'])) ||
        ([
              'activiti\$activitiReview',
              'activiti\$activitiReviewPooled',
            ].contains(workflow) &&
            [
              'wf:activitiReviewTask',
              'wf:approvedTask',
              'wf:rejectedTask',
            ].contains(task['name']));
  }

  factory WorkflowTaskForm.fromJson(
    String taskId,
    Map<String, dynamic> task,
    Map<String, dynamic> form,
  ) {
    final fields =
        ((form['definition'] as Map)['fields'] as List)
            .map((f) => WorkflowFormField(Map<String, dynamic>.from(f as Map)))
            .toList();
    final data = Map<String, dynamic>.from(form['formData'] as Map);
    final workflow = task['workflowInstance'] as Map? ?? {};
    String? reason;
    if (!supportsTask(task)) {
      reason = 'Task actions for this workflow are not supported yet.';
    } else if (task['isEditable'] != true ||
        (task['isPooled'] == true &&
            ((task['owner'] as Map?)?['userName'] == null ||
                task['isClaimable'] == true))) {
      reason = 'This task is not currently available for completion.';
    }
    final isAcknowledgement = [
      'wf:approvedTask',
      'wf:rejectedTask',
    ].contains(task['name']);
    final isDocumentApproval =
        workflow['name'] == 'activiti\$docApproveReject' &&
        task['name'] == 'scwf:activitiReviewTask';
    final outcomeFieldName =
        isDocumentApproval ? 'scwf:approveRejectOutcome' : 'wf:reviewOutcome';
    final outcomePropertyNames =
        isDocumentApproval
            ? [
              'scwf:approveRejectOutcome',
              '{http://www.jkl.com/model/workflow/1.0}approveRejectOutcome',
            ]
            : [
              'wf:reviewOutcome',
              '{http://www.alfresco.org/model/workflow/1.0}reviewOutcome',
            ];
    final isReview =
        isDocumentApproval ||
        task['name'] == 'wf:activitiReviewTask' &&
            [
              'activiti\$activitiReview',
              'activiti\$activitiReviewPooled',
            ].contains(workflow['name']);
    final outcome =
        isReview
            ? fields.where((f) => f.name == outcomeFieldName).firstOrNull
            : null;
    final outcomeName =
        ((task['properties'] as Map?)?['bpm_outcomePropertyName'] ??
                data['prop_bpm_outcomePropertyName'])
            ?.toString()
            .trim();
    if (isReview &&
        (outcome == null ||
            !outcome.supported ||
            outcome.key != 'prop_${outcomeFieldName.replaceAll(':', '_')}' ||
            outcome.protected ||
            !outcomePropertyNames.contains(outcomeName) ||
            outcome.choices.isEmpty ||
            outcome.choices.keys.any(
              (value) => !['Approve', 'Reject'].contains(value),
            ))) {
      reason ??= 'The review outcome control is unsupported or unavailable.';
    }
    final visible = <WorkflowFormField>[];
    for (final field in fields) {
      if (field.protected || (isReview && field.name == outcomeFieldName)) {
        continue;
      }
      if (field.metadata['type'] == 'association' &&
          field.name == 'bpm:assignee' &&
          (data[field.key]?.toString().isNotEmpty ?? false)) {
        continue;
      }
      if (!field.required && field.name != 'bpm:comment') continue;
      if (!field.supported) {
        reason ??=
            'Required field "${field.label}" needs an unsupported control.';
      } else {
        visible.add(field);
      }
    }
    final transitions = <String, String>{};
    final node = (task['definition'] as Map?)?['node'] as Map?;
    for (final raw in node?['transitions'] as List? ?? []) {
      final transition = raw as Map;
      if (transition['isHidden'] != true && transition['id'] is String) {
        transitions[transition['id'] as String] =
            (transition['title'] ?? transition['id']).toString();
      }
    }
    if (transitions.isEmpty) {
      reason ??= 'No task completion action is available.';
    }
    // Only the validated standard completion transition can be submitted.
    if (transitions.keys.any((key) => key != 'Next')) {
      reason ??= 'This task uses an unsupported transition.';
    }
    final actions = <WorkflowTaskAction>[];
    if (isReview && outcome != null && transitions.containsKey('Next')) {
      for (final choice in outcome.choices.entries) {
        if (outcome.validate(choice.key) != null) {
          reason ??=
              'The review outcome does not satisfy the server form rules.';
        }
        actions.add(
          WorkflowTaskAction(
            id: choice.key,
            label: choice.value,
            transitionId: 'Next',
            properties: {outcome.key: choice.key},
            requiresConfirmation: choice.key == 'Reject',
          ),
        );
      }
    } else if (!isReview) {
      for (final transition in transitions.entries) {
        actions.add(
          WorkflowTaskAction(
            id: transition.key,
            label: isAcknowledgement ? 'Acknowledge' : transition.value,
            transitionId: transition.key,
          ),
        );
      }
    }
    return WorkflowTaskForm._(
      taskId,
      sha256
          .convert(
            utf8.encode(jsonEncode(_canonical({'task': task, 'form': form}))),
          )
          .toString(),
      visible,
      data,
      transitions,
      reason,
      actions,
    );
  }

  Map<String, String> get initialValues => {
    for (final f in fields)
      f.key: (data[f.key] ?? f.metadata['defaultValue'] ?? '').toString(),
  };

  Map<String, dynamic> submission(Map<String, String> values, String actionId) {
    if (unavailableReason != null) throw StateError(unavailableReason!);
    final action = actions.where((a) => a.id == actionId).firstOrNull;
    if (action == null) {
      throw StateError('Task action is unavailable');
    }
    final result = <String, dynamic>{'prop_transitions': action.transitionId};
    for (final field in fields) {
      final text = values[field.key] ?? '';
      final error = field.validate(text);
      if (error != null) throw FormatException(error);
      result[field.key] = field.value(text);
    }
    result.addAll(action.properties);
    return result;
  }
}

dynamic _canonical(dynamic value) {
  if (value is Map) {
    return SplayTreeMap<String, dynamic>.from({
      for (final entry in value.entries)
        entry.key.toString(): _canonical(entry.value),
    });
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}
