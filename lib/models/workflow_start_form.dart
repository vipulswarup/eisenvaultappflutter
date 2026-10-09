import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'workflow_task_form.dart';

class WorkflowDefinition {
  final String id, name, title;
  const WorkflowDefinition(this.id, this.name, this.title);
  bool get supported => [
    'activiti\$activitiAdhoc',
    'activiti\$activitiReview',
    'activiti\$activitiReviewPooled',
  ].contains(name);
  bool get usesGroupAssignee => name == 'activiti\$activitiReviewPooled';
  factory WorkflowDefinition.fromJson(Map row) => WorkflowDefinition(
    row['id'] as String,
    row['name'] as String,
    (row['title'] ?? row['name']).toString(),
  );
}

class WorkflowAssignee {
  final String username, displayName, nodeRef;
  final bool isGroup;
  const WorkflowAssignee(
    this.username,
    this.displayName,
    this.nodeRef, {
    this.isGroup = false,
  });
}

class WorkflowStartNotSubmitted implements Exception {
  final String message;
  const WorkflowStartNotSubmitted(this.message);
  @override
  String toString() => message;
}

class WorkflowStartForm {
  final WorkflowDefinition definition;
  final String nodeId, documentName, fingerprint;
  final List<WorkflowFormField> fields;
  final Map<String, dynamic> defaults;
  final String? unavailableReason;
  bool get usesGroupAssignee => definition.usesGroupAssignee;
  WorkflowStartForm._(
    this.definition,
    this.nodeId,
    this.documentName,
    this.fingerprint,
    this.fields,
    this.defaults,
    this.unavailableReason,
  );
  factory WorkflowStartForm.fromJson(
    WorkflowDefinition definition,
    Map<String, dynamic> node,
    Map<String, dynamic> form,
  ) {
    final fields = <WorkflowFormField>[];
    String? reason =
        definition.supported
            ? null
            : 'Starting this workflow is not supported yet.';
    final metadata = (form['definition'] as Map?)?['fields'] as List? ?? [];
    var hasAssignee = false, hasPackage = false;
    for (final raw in metadata) {
      final f = WorkflowFormField(Map<String, dynamic>.from(raw as Map));
      if ([
        'bpm:assignee',
        'bpm:groupAssignee',
        'packageItems',
      ].contains(f.name)) {
        final groupAssignee = f.name == 'bpm:groupAssignee';
        final assignee = f.name == 'bpm:assignee' || groupAssignee;
        final expected =
            f.name == 'bpm:assignee'
                ? 'assoc_bpm_assignee'
                : groupAssignee
                ? 'assoc_bpm_groupAssignee'
                : 'assoc_packageItems';
        if (f.metadata['type'] != 'association' ||
            f.key != expected ||
            f.protected ||
            (assignee && groupAssignee != definition.usesGroupAssignee) ||
            (assignee && f.metadata['endpointMany'] == true) ||
            (f.name == 'bpm:assignee' &&
                f.metadata['endpointType'] != 'cm:person') ||
            (groupAssignee &&
                f.metadata['endpointType'] != 'cm:authorityContainer')) {
          reason ??=
              'The workflow assignment or document control is unsupported.';
        }
        if (assignee) hasAssignee = true;
        if (f.name == 'packageItems') hasPackage = true;
        continue;
      }
      if (f.protected) continue;
      if (!f.required &&
          ![
            'bpm:workflowDescription',
            'bpm:workflowDueDate',
            'bpm:workflowPriority',
            'bpm:comment',
          ].contains(f.name)) {
        continue;
      }
      final date =
          f.name == 'bpm:workflowDueDate' &&
          ['date', 'datetime'].contains(f.dataType) &&
          f.constraints.isEmpty &&
          f.metadata['repeating'] != true;
      if (!f.supported && !date) {
        reason ??= 'Required form control "${f.label}" is unsupported.';
      } else {
        fields.add(f);
      }
    }
    if (!hasAssignee || !hasPackage) {
      reason ??= 'The workflow assignment or document control is missing.';
    }
    if (node['isFile'] != true) {
      reason ??= 'Select a document to start a workflow.';
    }
    return WorkflowStartForm._(
      definition,
      node['id'] as String,
      node['name'] as String,
      sha256
          .convert(
            utf8.encode(
              jsonEncode(
                _sort({
                  'definition': definition.id,
                  'node': node,
                  'form': form,
                }),
              ),
            ),
          )
          .toString(),
      fields,
      Map<String, dynamic>.from(form['formData'] as Map? ?? {}),
      reason,
    );
  }
  Map<String, String> get initialValues => {
    for (final f in fields)
      f.key: (defaults[f.key] ?? f.metadata['defaultValue'] ?? '').toString(),
  };
  Map<String, dynamic> submission(
    Map<String, String> values,
    WorkflowAssignee person,
  ) {
    if (unavailableReason != null) {
      throw WorkflowStartNotSubmitted(unavailableReason!);
    }
    if (person.isGroup != definition.usesGroupAssignee) {
      throw const WorkflowStartNotSubmitted(
        'Choose an assignee of the type required by this workflow.',
      );
    }
    final body = <String, dynamic>{
      'assoc_packageItems_added': 'workspace://SpacesStore/$nodeId',
    };
    body[definition.usesGroupAssignee
            ? 'assoc_bpm_groupAssignee_added'
            : 'assoc_bpm_assignee_added'] =
        person.nodeRef;
    for (final f in fields) {
      final value = values[f.key] ?? '';
      if (f.dataType == 'date' || f.dataType == 'datetime') {
        if (value.isEmpty && !f.required) continue;
        final date = DateTime.tryParse(value);
        if (date == null) {
          throw WorkflowStartNotSubmitted('Choose a valid ${f.label}.');
        }
        body[f.key] = date.toUtc().toIso8601String();
      } else {
        final error = f.validate(value);
        if (error != null) throw WorkflowStartNotSubmitted(error);
        body[f.key] = f.value(value);
      }
    }
    // Preserve built-in notification defaults; optional custom fields are omitted.
    for (final key in ['prop_wf_notifyMe', 'prop_bpm_sendEMailNotifications']) {
      if (defaults[key] is bool) body[key] = defaults[key];
    }
    return body;
  }
}

dynamic _sort(dynamic value) {
  if (value is Map) {
    return {
      for (final k in value.keys.map((k) => k.toString()).toList()..sort())
        k: _sort(value[k]),
    };
  }
  if (value is List) return value.map(_sort).toList();
  return value;
}

/// Conservative ACL filter: unrecognized grants do not establish read access.
bool hasDocumentReadAccess(
  Map<String, dynamic> node,
  Set<String> authorities, {
  bool membershipsKnown = true,
}) {
  final permissions = node['permissions'] as Map?;
  if (permissions == null) return false;
  final owner =
      (node['properties'] as Map?)?['cm:owner'] ??
      (node['createdByUser'] as Map?)?['id'];
  final effective = {
    ...authorities,
    if (owner is String && authorities.contains(owner)) 'ROLE_OWNER',
  };
  final entries = [
    ...permissions['locallySet'] as List? ?? [],
    ...permissions['inherited'] as List? ?? [],
  ];
  final applicable = entries.where(
    (row) => effective.contains(row['authorityId']),
  );
  if (!membershipsKnown &&
      entries.any(
        (row) =>
            row['authorityId'].toString().startsWith('GROUP_') &&
            row['accessStatus'] != 'ALLOWED',
      )) {
    return false;
  }
  // Unknown denies fail closed; a narrower denied custom role may still read on the server.
  if (applicable.any((row) => row['accessStatus'] != 'ALLOWED')) return false;
  const readable = {
    'Consumer',
    'Contributor',
    'Collaborator',
    'Coordinator',
    'Editor',
    'Viewer',
    'Read',
    'ReadContent',
    'All',
    'SiteConsumer',
    'SiteContributor',
    'SiteCollaborator',
    'SiteManager',
  };
  return applicable.any((row) => readable.contains(row['name']));
}
