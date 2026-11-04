import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/account_avatar_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../providers/vault_lock_provider.dart';
import '../providers/vault_providers.dart';
import '../widgets/vault_lock_gate.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(vaultNotesProvider);

    // Going back out of the Vault locks it again.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(vaultLockProvider.notifier).lock();
      },
      child: VaultLockGate(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Vault'),
            actions: const [AccountAvatarButton()],
          ),
          body: notesAsync.when(
            data: (notes) {
              if (notes.isEmpty) {
                return const EmptyState(
                  icon: Icons.lock_outline,
                  message: 'No notes yet',
                );
              }
              return ListView.separated(
                itemCount: notes.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final snippet = note.body.split('\n').first;
                  return FadeSlideIn(
                    delay: FadeSlideIn.staggerDelay(index),
                    child: ListTile(
                      title: Text(note.title),
                      subtitle: Text(
                        snippet.isEmpty
                            ? DateFormat.yMMMd().format(note.updatedAt)
                            : snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => context.push('/more/vault/note/${note.id}'),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('Something went wrong: $error')),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/more/vault/new'),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
