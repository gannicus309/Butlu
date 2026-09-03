import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../../auth/providers/family_members_provider.dart';
import '../providers/status_providers.dart';

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class PickupScreen extends ConsumerWidget {
  const PickupScreen({super.key});

  Future<void> _setCustomStatus(BuildContext context, WidgetRef ref, String uid) async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set your status'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Status'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    final trimmed = label?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    await ref.read(statusRepositoryProvider).setStatus(uid, trimmed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusesAsync = ref.watch(statusesProvider);
    final membersAsync = ref.watch(familyMembersProvider);
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Who's got pickup")),
      body: statusesAsync.when(
        data: (statuses) {
          final members = membersAsync.value ?? const {};
          final statusByUid = {for (final s in statuses) s.uid: s};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in members.entries)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(entry.value.isNotEmpty
                          ? entry.value[0].toUpperCase()
                          : '?'),
                    ),
                    title: Text(entry.value),
                    subtitle: Text(
                      statusByUid[entry.key] != null
                          ? '${statusByUid[entry.key]!.label} · '
                              '${_relativeTime(statusByUid[entry.key]!.updatedAt)}'
                          : 'No status set',
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Set your status',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in statusPresets)
                    ActionChip(
                      label: Text(preset),
                      onPressed: currentUid == null
                          ? null
                          : () => ref
                              .read(statusRepositoryProvider)
                              .setStatus(currentUid, preset),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Custom'),
                    onPressed: currentUid == null
                        ? null
                        : () => _setCustomStatus(context, ref, currentUid),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Something went wrong: $error')),
      ),
    );
  }
}
