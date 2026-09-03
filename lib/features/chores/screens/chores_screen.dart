import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/account_avatar_button.dart';
import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../../auth/providers/family_members_provider.dart';
import '../models/chore_task.dart';
import '../providers/chore_providers.dart';

class ChoresScreen extends ConsumerWidget {
  const ChoresScreen({super.key});

  Future<void> _addUnclaimedTask(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New chore'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'What needs doing?'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    await ref.read(choreRepositoryProvider).addTask(
          title: trimmed,
          createdByUid: uid,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(choreTasksProvider);
    final membersAsync = ref.watch(familyMembersProvider);
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores'),
        actions: const [AccountAvatarButton()],
      ),
      body: tasksAsync.when(
        data: (tasks) {
          final unclaimed = tasks.where((t) => t.assignedToUid == null).toList();
          final claimed = tasks.where((t) => t.assignedToUid != null).toList();
          final members = membersAsync.value ?? const {};

          final takenTitles = tasks.map((t) => t.title.toLowerCase()).toSet();
          final suggestions = choreSuggestions
              .where((s) => !takenTitles.contains(s.toLowerCase()))
              .toList();

          final byAssignee = <String, List<ChoreTask>>{};
          for (final task in claimed) {
            byAssignee.putIfAbsent(task.assignedToUid!, () => []).add(task);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                "Who's got it?",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final task in unclaimed)
                    ActionChip(
                      avatar: const Icon(Icons.add_task, size: 18),
                      label: Text(task.title),
                      onPressed: currentUid == null
                          ? null
                          : () => ref
                              .read(choreRepositoryProvider)
                              .claimTask(task.id, currentUid),
                    ),
                  for (final suggestion in suggestions)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(suggestion),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      onPressed: currentUid == null
                          ? null
                          : () => ref.read(choreRepositoryProvider).addTask(
                                title: suggestion,
                                createdByUid: currentUid,
                                assignedToUid: currentUid,
                              ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),
              if (byAssignee.isEmpty)
                Text(
                  'Nothing claimed yet',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final entry in byAssignee.entries) ...[
                  Text(
                    members[entry.key] ?? 'Someone',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final task in entry.value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: false,
                        onChanged: (_) => ref
                            .read(choreRepositoryProvider)
                            .markDone(task.id),
                      ),
                      title: Text(task.title),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(choreRepositoryProvider)
                            .deleteTask(task.id),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Something went wrong: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addUnclaimedTask(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
