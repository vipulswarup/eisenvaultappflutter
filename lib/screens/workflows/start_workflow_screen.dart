import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/workflow_start_form.dart';
import '../../models/workflow_task_form.dart';
import '../../services/workflows/alfresco_workflow_service.dart';
import '../../services/workflows/workflow_draft_store.dart';

class StartWorkflowScreen extends StatefulWidget {
  final WorkflowStartService service;
  final String nodeId, documentName, accountId;
  const StartWorkflowScreen({
    super.key,
    required this.service,
    required this.nodeId,
    required this.documentName,
    required this.accountId,
  });
  @override
  State<StartWorkflowScreen> createState() => _StartWorkflowScreenState();
}

class _StartWorkflowScreenState extends State<StartWorkflowScreen> {
  final _key = GlobalKey<FormState>();
  final _assigneeKey = GlobalKey<FormFieldState<WorkflowAssignee>>();
  late Future<List<WorkflowDefinition>> _definitions;
  WorkflowDefinition? _definition;
  WorkflowStartForm? _form;
  WorkflowAssignee? _assignee;
  WorkflowDraftStore? _draft;
  Map<String, String> _values = {};
  Future<void> _writes = Future.value();
  bool _loading = false, _busy = false, _locked = false;
  String? _error, _notice;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _definitions = widget.service.getStartDefinitions();
  }

  Future<void> _select(WorkflowDefinition definition) async {
    final generation = ++_generation;
    setState(() {
      _definition = definition;
      _loading = true;
      _form = null;
      _error = null;
      _notice = null;
      _assignee = null;
      _locked = false;
    });
    try {
      await _writes;
      final form = await widget.service.getStartForm(definition, widget.nodeId);
      final draft = WorkflowDraftStore(
        widget.accountId,
        'start:${widget.nodeId}:${definition.id}',
      );
      final saved = await draft.read();
      final values = form.initialValues;
      String? notice;
      if (saved != null) {
        if (saved['fingerprint'] == form.fingerprint) {
          values.addAll(Map<String, String>.from(saved['values'] as Map));
        } else if ((saved['values'] as Map?)?['startAttemptPending'] ==
            'true') {
          // Never discard an uncertain start merely because metadata changed.
          values['startAttemptPending'] = 'true';
        } else {
          await draft.clear();
          notice =
              'The document or form changed. Your saved entries were discarded.';
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _form = form;
        _draft = draft;
        _values = values;
        _notice = notice;
        _loading = false;
        _locked = values['startAttemptPending'] == 'true';
        if (values['assigneeUsername'] != null &&
            values['assigneeLabel'] != null &&
            values['assigneeRef'] != null &&
            values['assigneeIsGroup'] == form.usesGroupAssignee.toString()) {
          _assignee = WorkflowAssignee(
            values['assigneeUsername']!,
            values['assigneeLabel']!,
            values['assigneeRef']!,
            isGroup: form.usesGroupAssignee,
          );
        }
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _save(String key, String value) {
    _values[key] = value;
    final values = Map<String, String>.from(_values),
        form = _form!,
        draft = _draft!;
    _writes = _writes.then((_) => draft.save(form.fingerprint, values)).catchError((
      Object error,
    ) {
      if (mounted) {
        setState(
          () =>
              _notice =
                  'Your draft could not be saved. Keep this screen open until submitted.',
        );
      }
    });
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) {
      setState(
        () => _error = 'Complete the required fields to start this workflow.',
      );
      return;
    }
    final assignee = _assigneeKey.currentState?.value ?? _assignee;
    if (assignee == null) {
      setState(() => _error = 'Select an assignee to start this workflow.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _form!.submission(_values, assignee);
      await _writes;
      _values['startAttemptPending'] = 'true';
      // Persist the attempt before sending it, preventing a duplicate after app restart.
      await _draft!.save(_form!.fingerprint, _values);
      final id = await widget.service.startWorkflow(_form!, _values, assignee);
      await _draft!.clear();
      if (mounted) {
        // PopScope blocks user-initiated back navigation while a start is pending.
        // Release it after confirmed creation so the success route can pop.
        setState(() => _busy = false);
        Navigator.pop(context, id);
      }
    } catch (e) {
      if (e is WorkflowStartNotSubmitted) {
        _values.remove('startAttemptPending');
        try {
          await _draft!.save(_form!.fingerprint, _values);
        } catch (_) {
          _notice = 'Your draft could not be saved.';
        }
      } else if (_values['startAttemptPending'] == 'true') {
        _locked = true;
      }
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Start workflow')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(widget.documentName),
                  subtitle: const Text(
                    'This document will be included in the workflow.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<WorkflowDefinition>>(
                future: _definitions,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        Text(snapshot.error.toString()),
                        TextButton(
                          onPressed:
                              () => setState(
                                () =>
                                    _definitions =
                                        widget.service.getStartDefinitions(),
                              ),
                          child: const Text('Retry'),
                        ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  if (snapshot.data!.isEmpty) {
                    return const Text('No workflows are available.');
                  }
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Workflow',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _definition?.id,
                    isExpanded: true,
                    items:
                        snapshot.data!
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  '${d.title}${d.supported ? '' : ' (unavailable)'}',
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _busy || _locked
                            ? null
                            : (id) => _select(
                              snapshot.data!.singleWhere((d) => d.id == id),
                            ),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_notice!),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_locked)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'A start attempt may have succeeded. Check the workflow on the server before starting another. This saved attempt is protected against duplicate submission.',
                  ),
                ),
              if (_form?.unavailableReason != null)
                Text(_form!.unavailableReason!),
              if (_form != null && _form!.unavailableReason == null)
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _key,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workflow details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          FormField<WorkflowAssignee>(
                            key: _assigneeKey,
                            initialValue: _assignee,
                            validator:
                                (value) =>
                                    value == null ? 'Select an assignee' : null,
                            builder:
                                (field) => InkWell(
                                  onTap:
                                      _busy || _locked
                                          ? null
                                          : () async {
                                            final person = await showDialog<
                                              WorkflowAssignee
                                            >(
                                              context: context,
                                              builder:
                                                  (_) => _AssigneePicker(
                                                    service: widget.service,
                                                    nodeId: widget.nodeId,
                                                    isGroup:
                                                        _form!
                                                            .usesGroupAssignee,
                                                  ),
                                            );
                                            if (person == null || !mounted) {
                                              return;
                                            }
                                            field.didChange(person);
                                            _assignee = person;
                                            _save(
                                              'assigneeUsername',
                                              person.username,
                                            );
                                            _save(
                                              'assigneeLabel',
                                              person.displayName,
                                            );
                                            _save(
                                              'assigneeRef',
                                              person.nodeRef,
                                            );
                                            _save(
                                              'assigneeIsGroup',
                                              person.isGroup.toString(),
                                            );
                                          },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText:
                                          '${_form!.usesGroupAssignee ? 'Review group' : 'Assignee'} *',
                                      border: const OutlineInputBorder(),
                                      errorText: field.errorText,
                                      suffixIcon: const Icon(
                                        Icons.person_search_outlined,
                                      ),
                                    ),
                                    child: Text(
                                      field.value == null
                                          ? _form!.usesGroupAssignee
                                              ? 'Search groups with an eligible member'
                                              : 'Search users with document access'
                                          : field.value!.isGroup
                                          ? field.value!.displayName
                                          : '${field.value!.displayName} (${field.value!.username})',
                                    ),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 20),
                          for (final f in _form!.fields)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _control(f),
                            ),
                          const Divider(height: 32),
                          FilledButton.icon(
                            onPressed: _busy || _locked ? null : _submit,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(_busy ? 'Starting…' : 'Start workflow'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _control(WorkflowFormField f) {
    final decoration = InputDecoration(
      labelText: '${f.label}${f.required ? ' *' : ''}',
      border: const OutlineInputBorder(),
      alignLabelWithHint: true,
    );
    final key = ValueKey('$_generation:${f.key}');
    if (f.name == 'bpm:workflowDueDate') {
      return FormField<String>(
        key: key,
        initialValue: _values[f.key],
        validator:
            (v) =>
                f.required && (v?.isEmpty ?? true) ? 'Choose a due date' : null,
        builder: (field) {
          final date = DateTime.tryParse(field.value ?? '')?.toLocal();
          return InputDecorator(
            decoration: decoration.copyWith(errorText: field.errorText),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date == null
                        ? 'No due date'
                        : DateFormat.yMMMd().format(date),
                  ),
                ),
                IconButton(
                  tooltip: 'Choose due date',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed:
                      _busy || _locked
                          ? null
                          : () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: date ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (selected != null && mounted) {
                              final value = selected.toUtc().toIso8601String();
                              field.didChange(value);
                              _save(f.key, value);
                            }
                          },
                ),
                if (date != null && !f.required)
                  IconButton(
                    tooltip: 'Clear due date',
                    onPressed:
                        _busy || _locked
                            ? null
                            : () {
                              field.didChange('');
                              _save(f.key, '');
                            },
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          );
        },
      );
    }
    if (f.choices.isNotEmpty) {
      return DropdownButtonFormField<String>(
        key: key,
        initialValue:
            f.choices.containsKey(_values[f.key]) ? _values[f.key] : null,
        decoration: decoration,
        isExpanded: true,
        items:
            f.choices.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
        onChanged:
            _busy || _locked
                ? null
                : (v) {
                  if (v != null) _save(f.key, v);
                },
        validator: (v) => f.validate(v ?? ''),
      );
    }
    return TextFormField(
      key: key,
      initialValue: _values[f.key],
      enabled: !_busy && !_locked,
      decoration: decoration,
      maxLines:
          ['bpm:workflowDescription', 'bpm:comment'].contains(f.name) ? 3 : 1,
      keyboardType:
          f.dataType == 'int' ? TextInputType.number : TextInputType.multiline,
      onChanged: (v) => _save(f.key, v),
      validator: (v) => f.validate(v ?? ''),
    );
  }
}

class _AssigneePicker extends StatefulWidget {
  final WorkflowStartService service;
  final String nodeId;
  final bool isGroup;
  const _AssigneePicker({
    required this.service,
    required this.nodeId,
    required this.isGroup,
  });
  @override
  State<_AssigneePicker> createState() => _AssigneePickerState();
}

class _AssigneePickerState extends State<_AssigneePicker> {
  final _query = TextEditingController();
  List<WorkflowAssignee> _people = [];
  String? _error;
  bool _loading = false;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().length < 2) {
      setState(() => _error = 'Enter at least two characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _people = [];
    });
    try {
      final people =
          widget.isGroup
              ? await widget.service.searchGroups(widget.nodeId, _query.text)
              : await widget.service.searchAssignees(
                widget.nodeId,
                _query.text,
              );
      if (mounted) setState(() => _people = people);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.isGroup ? 'Select review group' : 'Select assignee'),
    content: SizedBox(
      width: 480,
      height: 360,
      child: Column(
        children: [
          TextField(
            controller: _query,
            decoration: InputDecoration(
              labelText: widget.isGroup ? 'Search groups' : 'Search users',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _loading ? null : (_) => _search(),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isGroup
                ? 'Only groups with a member who can read this document are shown.'
                : 'Only users with verified document access are shown. Search checks up to 25 matches; narrow the name if needed.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : _search,
              child: const Text('Search'),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          Expanded(
            child: ListView(
              children: [
                for (final person in _people)
                  ListTile(
                    title: Text(person.displayName),
                    subtitle: Text(widget.isGroup ? 'Group' : person.username),
                    onTap: () => Navigator.pop(context, person),
                  ),
                if (!_loading && _people.isEmpty)
                  ListTile(
                    title: Text(
                      widget.isGroup
                          ? 'No matching groups with an eligible member.'
                          : 'No matching users with verified access.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
