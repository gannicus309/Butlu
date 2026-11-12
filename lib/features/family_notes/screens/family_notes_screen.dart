import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../providers/family_notes_providers.dart';

/// What to ask the Gemini app for, so its memory of the family can be
/// pasted here.
const _geminiAppPrompt =
    'Summarise what you know about my family that would help plan meals, '
    'shopping and chores: who lives with us, food likes and dislikes, '
    'diets and allergies, cooking habits, weekly routines. Short bullet '
    'points. Leave out work details and anything medical beyond '
    'allergies.';

/// More → Family notes: free text Gemini reads before every question.
class FamilyNotesScreen extends ConsumerStatefulWidget {
  const FamilyNotesScreen({super.key});

  @override
  ConsumerState<FamilyNotesScreen> createState() => _FamilyNotesScreenState();
}

class _FamilyNotesScreenState extends ConsumerState<FamilyNotesScreen> {
  final _controller = TextEditingController();
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(familyNotesRefProvider).set({
        'text': _controller.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': ref.read(authStateProvider).value?.uid,
      });
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() => _dirty = false);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(persist: false, content: Text('Family notes saved')),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(persist: false, content: Text("Couldn't save: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(familyNotesProvider);
    // Fill the box once from the saved notes; don't overwrite typing when
    // the other phone saves.
    if (!_loaded && notes.hasValue) {
      _controller.text = notes.value!;
      _loaded = true;
    }
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family notes'),
          actions: [
            TextButton(
              onPressed: _dirty && !_saving ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Gemini reads these before every question in Ask '
                    'Gemini, so answers fit your household. Both of you '
                    'can edit them.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    minLines: 12,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (!_dirty) setState(() => _dirty = true);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText:
                          '- Vegetarian on weekdays\n'
                          '- No mushrooms\n'
                          '- Big shop on Saturdays at Rewe\n'
                          '- Quick dinners (under 30 min) on office days',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bring over what your Gemini app knows',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Copy this question, ask it in the Gemini app, '
                            'and paste the answer above. Check it first -- '
                            'everything here is sent to Gemini.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _geminiAppPrompt,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                              onPressed: () {
                                Clipboard.setData(
                                  const ClipboardData(text: _geminiAppPrompt),
                                );
                                HapticFeedback.selectionClick();
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(
                                      persist: false,
                                      content: Text(
                                        'Copied. Paste it into the Gemini app.',
                                      ),
                                    ),
                                  );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy question'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
