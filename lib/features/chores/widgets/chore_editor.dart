import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chore.dart';

/// What the editor sheet returns.
sealed class ChoreEditResult {}

class ChoreSaved extends ChoreEditResult {
  ChoreSaved(this.chore);
  final Chore chore;
}

class ChoreDeleted extends ChoreEditResult {}

/// Create or edit a task: title, details, date and time, subtype, tags,
/// repeat, priority flag and who it's for. [chore] with an empty id is a
/// new task (possibly pre-filled from a suggestion).
Future<ChoreEditResult?> showChoreEditor(
  BuildContext context, {
  required Chore chore,
  required List<String> assignees,
  required List<String> knownTags,
}) => showModalBottomSheet<ChoreEditResult>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) =>
      _ChoreEditor(chore: chore, assignees: assignees, knownTags: knownTags),
);

class _ChoreEditor extends StatefulWidget {
  const _ChoreEditor({
    required this.chore,
    required this.assignees,
    required this.knownTags,
  });

  final Chore chore;
  final List<String> assignees;
  final List<String> knownTags;

  @override
  State<_ChoreEditor> createState() => _ChoreEditorState();
}

class _ChoreEditorState extends State<_ChoreEditor> {
  late final _title = TextEditingController(text: widget.chore.title);
  late final _details = TextEditingController(text: widget.chore.details);
  final _tagInput = TextEditingController();
  late Chore _c = widget.chore;

  bool get _isNew => widget.chore.id.isEmpty;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _c.dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null) return;
    final old = _c.dueAt;
    setState(
      () => _c = _c.copyWith(
        dueAt: DateTime(
          d.year,
          d.month,
          d.day,
          _c.hasTime && old != null ? old.hour : 0,
          _c.hasTime && old != null ? old.minute : 0,
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final base = _c.dueAt ?? DateTime.now();
    final t = await showTimePicker(
      context: context,
      initialTime: _c.hasTime
          ? TimeOfDay.fromDateTime(base)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (t == null) return;
    setState(
      () => _c = _c.copyWith(
        dueAt: DateTime(base.year, base.month, base.day, t.hour, t.minute),
        hasTime: true,
      ),
    );
  }

  void _quickDate(int days) {
    final n = DateTime.now();
    setState(
      () => _c = _c.copyWith(
        dueAt: DateTime(n.year, n.month, n.day + days),
        hasTime: false,
      ),
    );
  }

  void _addTag(String raw) {
    final tag = raw.trim().replaceAll('#', '').toLowerCase();
    _tagInput.clear();
    if (tag.isEmpty || _c.tags.contains(tag)) return;
    setState(() => _c = _c.copyWith(tags: [..._c.tags, tag]));
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (_tagInput.text.trim().isNotEmpty) _addTag(_tagInput.text);
    Navigator.pop(
      context,
      ChoreSaved(_c.copyWith(title: title, details: _details.text.trim())),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.outline,
        letterSpacing: 0.8,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = _c.kind;
    final due = _c.dueAt;
    final suggestedTags = [
      for (final t in widget.knownTags)
        if (!_c.tags.contains(t)) t,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Expanded(
                    child: Text(
                      _isNew ? 'New task' : 'Details',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _save,
                    child: Text(_isNew ? 'Add' : 'Done'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: kind.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        kind.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: kind.color,
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _title,
                    autofocus: _isNew && _title.text.isEmpty,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.titleLarge,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                    ),
                  ),
                  TextField(
                    controller: _details,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Details',
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.flag,
                      color: ChoreKind.priority.color,
                    ),
                    title: const Text('Priority'),
                    subtitle: const Text('Shown red, always at the top'),
                    value: _c.priority,
                    onChanged: (v) =>
                        setState(() => _c = _c.copyWith(priority: v)),
                  ),
                  _label('Date'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.today, size: 18),
                        label: const Text('Today'),
                        onPressed: () => _quickDate(0),
                      ),
                      ActionChip(
                        label: const Text('Tomorrow'),
                        onPressed: () => _quickDate(1),
                      ),
                      ActionChip(
                        label: const Text('Next week'),
                        onPressed: () => _quickDate(7),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.event, size: 18),
                        label: Text(
                          due == null
                              ? 'Pick date'
                              : DateFormat.MMMEd().format(due),
                        ),
                        onPressed: _pickDate,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.schedule, size: 18),
                        label: Text(
                          _c.hasTime && due != null
                              ? DateFormat.jm().format(due)
                              : 'Add time',
                        ),
                        onPressed: _pickTime,
                      ),
                      if (due != null)
                        ActionChip(
                          label: const Text('No date'),
                          onPressed: () => setState(
                            () => _c = _c.copyWith(
                              clearDue: true,
                              hasTime: false,
                            ),
                          ),
                        ),
                    ],
                  ),
                  _label('Repeat'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in ChoreRepeat.values)
                        ChoiceChip(
                          label: Text(r.label),
                          selected: _c.repeat == r,
                          onSelected: (_) => setState(() {
                            _c = _c.copyWith(repeat: r);
                            // A repeating task needs a first date.
                            if (r != ChoreRepeat.none && _c.dueAt == null) {
                              final n = DateTime.now();
                              _c = _c.copyWith(
                                dueAt: DateTime(n.year, n.month, n.day),
                              );
                            }
                          }),
                        ),
                    ],
                  ),
                  _label('Subtype'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in ChoreSubtype.values)
                        ChoiceChip(
                          label: Text('${s.emoji} ${s.label}'),
                          selected: _c.subtype == s,
                          onSelected: (_) =>
                              setState(() => _c = _c.copyWith(subtype: s)),
                        ),
                    ],
                  ),
                  _label('Assigned to'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Anyone'),
                        selected: _c.assignee == null,
                        onSelected: (_) => setState(
                          () => _c = _c.copyWith(clearAssignee: true),
                        ),
                      ),
                      for (final a in widget.assignees)
                        ChoiceChip(
                          label: Text(a),
                          selected: _c.assignee == a,
                          onSelected: (_) =>
                              setState(() => _c = _c.copyWith(assignee: a)),
                        ),
                    ],
                  ),
                  _label('Tags'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final t in _c.tags)
                        InputChip(
                          label: Text('#$t'),
                          onDeleted: () => setState(
                            () =>
                                _c = _c.copyWith(tags: [..._c.tags]..remove(t)),
                          ),
                        ),
                      for (final t in suggestedTags.take(6))
                        ActionChip(
                          label: Text('+ #$t'),
                          onPressed: () => _addTag(t),
                        ),
                    ],
                  ),
                  TextField(
                    controller: _tagInput,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _addTag,
                    decoration: const InputDecoration(
                      prefixText: '#',
                      hintText: 'Add a tag',
                    ),
                  ),
                  if (!_isNew) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(context, ChoreDeleted()),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete task'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
