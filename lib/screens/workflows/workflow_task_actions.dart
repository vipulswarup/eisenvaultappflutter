import 'package:flutter/material.dart';
import '../../models/workflow_task_form.dart';
import '../../constants/colors.dart';
import '../../services/workflows/alfresco_workflow_service.dart';
import '../../services/workflows/workflow_draft_store.dart';

class WorkflowTaskActions extends StatefulWidget {
  final WorkflowActionService service;
  final String taskId, accountId;
  final ValueChanged<String> onCompleted;
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
      final action = _form!.actions.singleWhere((a) => a.id == transition);
      if (action.requiresConfirmation) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Reject task?'),
                content: const Text(
                  'This will submit a rejection for this review task.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(dialogContext).colorScheme.error,
                      foregroundColor:
                          Theme.of(dialogContext).colorScheme.onError,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(action.label),
                  ),
                ],
              ),
        );
        if (confirmed != true || !mounted) return;
      }
      await _writes;
      await widget.service.completeTask(_form!, _values, transition);
      await _draft.clear();
      if (mounted) widget.onCompleted(transition);
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
                      form.actions.any(
                            (a) => a.id == 'Approve' || a.id == 'Reject',
                          )
                          ? 'Review task'
                          : 'Complete task',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    for (final field in form.fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child:
                            field.choices.isNotEmpty
                                ? DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    '${form.fingerprint}:${field.key}',
                                  ),
                                  initialValue:
                                      field.choices.containsKey(
                                            _values[field.key],
                                          )
                                          ? _values[field.key]
                                          : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText:
                                        '${field.label}${field.required ? ' *' : ''}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignLabelWithHint: true,
                                    contentPadding: const EdgeInsets.all(16),
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
                                  validator:
                                      (value) => field.validate(value ?? ''),
                                )
                                : TextFormField(
                                  key: ValueKey(
                                    '${form.fingerprint}:${field.key}',
                                  ),
                                  initialValue: _values[field.key],
                                  enabled: !_submitting,
                                  decoration: InputDecoration(
                                    labelText:
                                        '${field.label}${field.required ? ' *' : ''}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignLabelWithHint: true,
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                  keyboardType:
                                      field.dataType == 'int'
                                          ? TextInputType.number
                                          : TextInputType.multiline,
                                  maxLines: field.name == 'bpm:comment' ? 3 : 1,
                                  onChanged: (value) => _save(field.key, value),
                                  validator:
                                      (value) => field.validate(value ?? ''),
                                ),
                      ),
                    const Divider(height: 32),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final action in form.actions)
                          if (action.id == 'Reject')
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                minimumSize: const Size(132, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                              ),
                              onPressed:
                                  _submitting ? null : () => _submit(action.id),
                              icon: const Icon(Icons.close_rounded, size: 20),
                              label: Text(
                                _submitting ? 'Submitting…' : action.label,
                              ),
                            )
                          else
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: EVColors.buttonBackground,
                                foregroundColor: EVColors.buttonForeground,
                                minimumSize: const Size(132, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                              ),
                              onPressed:
                                  _submitting ? null : () => _submit(action.id),
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: Text(
                                _submitting ? 'Submitting…' : action.label,
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
