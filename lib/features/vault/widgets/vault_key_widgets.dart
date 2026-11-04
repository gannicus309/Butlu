import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/vault_crypto.dart';
import '../providers/vault_key_provider.dart';

/// Shows the Vault's recovery key, to write down or save in a password
/// manager -- the only way back into the notes on a new phone.
Future<void> showRecoveryKeySheet(BuildContext context, VaultKey key) async {
  final text = await recoveryKeyFor(key);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Recovery key', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Your Vault notes are encrypted on this phone. Keep this key '
                'somewhere safe, like your password manager. You need it to '
                'open the Vault on a new phone or on your wife\'s phone. '
                'Without it, nobody (not even Butlu) can read the notes.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 16,
                    height: 1.5,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        persist: false,
                        content: Text(
                          'Copied. Paste it into your password manager, then '
                          'clear it from anywhere else.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shown instead of the notes when this phone doesn't have the family's
/// Vault key: type the recovery key in to unlock them.
class VaultRestoreView extends ConsumerStatefulWidget {
  const VaultRestoreView({super.key});

  @override
  ConsumerState<VaultRestoreView> createState() => _VaultRestoreViewState();
}

class _VaultRestoreViewState extends ConsumerState<VaultRestoreView> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(vaultKeyProvider.notifier)
        .restore(_controller.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.key_outlined, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Enter your recovery key',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          "This family's Vault is encrypted, and this phone doesn't have the "
          'key yet. Type or paste the recovery key from the phone that set '
          'it up (Vault → ⋯ → Recovery key).',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          maxLines: 3,
          minLines: 2,
          style: const TextStyle(fontFamily: 'Menlo', letterSpacing: 1),
          decoration: InputDecoration(
            hintText: 'XXXX-XXXX-XXXX-…',
            errorText: _error,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Unlock notes'),
        ),
      ],
    );
  }
}
