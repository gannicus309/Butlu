import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../models/vault_note.dart';
import '../providers/vault_providers.dart';
import '../widgets/vault_lock_gate.dart';

class NoteEditScreen extends ConsumerStatefulWidget {
  const NoteEditScreen({super.key, this.noteId});

  /// Null when creating a new note.
  final String? noteId;

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _initializeFrom(VaultNote note) {
    if (_initialized) return;
    _titleController.text = note.title;
    _bodyController.text = note.body;
    _initialized = true;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final repo = ref.read(vaultRepositoryProvider);

    if (widget.noteId == null) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return;
      await repo.addNote(
        title: title,
        body: _bodyController.text,
        createdByUid: uid,
      );
    } else {
      await repo.updateNote(
        widget.noteId!,
        title: title,
        body: _bodyController.text,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.noteId == null) return;
    await ref.read(vaultRepositoryProvider).deleteNote(widget.noteId!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.noteId != null) {
      final notes = ref.watch(vaultNotesProvider).value ?? const [];
      for (final note in notes) {
        if (note.id == widget.noteId) {
          _initializeFrom(note);
          break;
        }
      }
    }

    return VaultLockGate(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.noteId == null ? 'New note' : 'Edit note'),
          actions: [
            if (widget.noteId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            IconButton(icon: const Icon(Icons.check), onPressed: _save),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
