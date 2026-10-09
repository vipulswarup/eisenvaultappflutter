import 'package:flutter/material.dart';
import '../../models/workflow_task_form.dart';
import '../../services/workflows/alfresco_workflow_service.dart';
import '../../services/workflows/workflow_draft_store.dart';

class WorkflowTaskActions extends StatefulWidget {
  final WorkflowActionService service;
  final String taskId, accountId;
  final VoidCallback onCompleted;
  const WorkflowTaskActions({
    super.key,
    required this.service,
    required this.taskId,
    required this.accountId,
    required this.onCompleted,
  });
  @override
  State<WorkflowTaskActions> createState() => _WorkflowTaskActionsState();
}

class _WorkflowTaskActionsState extends State<WorkflowTaskActions> {
  final _formKey = GlobalKey<FormState>();
  late final WorkflowDraftStore _draft;
  WorkflowTaskForm? _form;
  Map<String, String> _values = {};
  bool _loading = true, _submitting = false;
  String? _error, _notice;
  Future<void> _writes = Future.value();
  @override
  void initState() {
    super.initState();
    _draft = WorkflowDraftStore(widget.accountId, widget.taskId);
    _load();
  }

  Future<void> _load() async {
    try {
      await _writes;
      final form = await widget.service.getTaskForm(widget.taskId);
      final saved = await _draft.read();
      var values = form.initialValues;
      String? notice;
      if (saved != null) {
        if (saved['fingerprint'] == form.fingerprint) {
          values.addAll(Map<String, String>.from(saved['values'] as Map));
        } else {
          await _draft.clear();
          notice = 'This task changed. Saved entries were discarded.';
        }
      }
      if (!mounted) return;
      setState(() {
        _form = form;
        _values = values;
        _loading = false;
        _notice = notice;
        _error = null;
      });
    } catch (e) {
      if (e is WorkflowTaskChanged) await _draft.clear();
      if (mounted) {
        setState(() {
          _loading = false;
          _form = null;
          _error = e.toString();
        });
      }
    }
  }

  void _save(String key, String value) {
    _values[key] = value;
    final values = Map<String, String>.from(_values);
    final fingerprint = _form!.fingerprint;
    _writes = _writes.then((_) => _draft.save(fingerprint, values)).catchError((
      Object _,
    ) {
      if (mounted) {
        setState(
          () =>
              _notice =
                  'Unable to save your draft. Keep this screen open until submitted.',
        );
      }
    });
  }

  Future<void> _submit(String transition) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _writes;
      await widget.service.completeTask(_form!, _values, transition);
      await _draft.clear();
      if (mounted) widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      if (e is WorkflowTaskChanged) {
        await _draft.clear();
        await _load();
        if (mounted) setState(() => _notice = e.toString());
      } else {
        // Refresh is mandatory after uncertain mutation responses; never automatically resubmit.
        setState(() {
          _error = '${e.toString()} Refresh the task before trying again.';
          _form = null;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    final form = _form;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_notice!),
          ),
        if (_error != null) Text(_error!),
        if (form == null)
          TextButton(
            onPressed:
                _submitting
                    ? null
                    : () {
                      setState(() => _loading = true);
                      _load();
                    },
            child: const Text('Refresh task form'),
          ),
        if (form?.unavailableReason != null) Text(form!.unavailableReason!),
        if (form != null && form.unavailableReason == null)
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete task',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final field in form.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child:
                        field.choices.isNotEmpty
                            ? DropdownButtonFormField<String>(
                              key: ValueKey('${form.fingerprint}:${field.key}'),
                              initialValue:
                                  field.choices.containsKey(_values[field.key])
                                      ? _values[field.key]
                                      : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText:
                                    '${field.label}${field.required ? ' *' : ''}',
                              ),
                              items:
                                  field.choices.entries
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e.key,
                                          child: Text(e.value),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  _submitting
                                      ? null
                                      : (value) {
                                        if (value != null) {
                                          _save(field.key, value);
                                        }
                                      },
                              validator: (value) => field.validate(value ?? ''),
                            )
                            : TextFormField(
                              key: ValueKey('${form.fingerprint}:${field.key}'),
                              initialValue: _values[field.key],
                              enabled: !_submitting,
                              decoration: InputDecoration(
                                labelText:
                                    '${field.label}${field.required ? ' *' : ''}',
                              ),
                              keyboardType:
                                  field.dataType == 'int'
                                      ? TextInputType.number
                                      : TextInputType.multiline,
                              maxLines: field.name == 'bpm:comment' ? 3 : 1,
                              onChanged: (value) => _save(field.key, value),
                              validator: (value) => field.validate(value ?? ''),
                            ),
                  ),
                for (final transition in form.transitions.entries)
                  FilledButton(
                    onPressed:
                        _submitting ? null : () => _submit(transition.key),
                    child: Text(_submitting ? 'Submitting…' : transition.value),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
