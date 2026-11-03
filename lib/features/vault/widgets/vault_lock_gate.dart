import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/vault_lock_provider.dart';

/// Hides [child] behind a lock screen until [vaultLockProvider] is unlocked.
///
/// [child] stays mounted (just offstage) while locked, so a half-written note
/// survives the app being backgrounded and re-locked -- it's simply hidden,
/// not painted, and unreachable by taps or VoiceOver until unlocked again.
class VaultLockGate extends ConsumerStatefulWidget {
  const VaultLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VaultLockGate> createState() => _VaultLockGateState();
}

class _VaultLockGateState extends ConsumerState<VaultLockGate> {
  @override
  void initState() {
    super.initState();
    // Prompt straight away on first showing, rather than making the user tap
    // "Unlock" just to get the Face ID sheet they already expect.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(vaultLockProvider.notifier).unlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(vaultLockProvider);

    return Stack(
      children: [
        Offstage(offstage: !lock.isUnlocked, child: widget.child),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: lock.isUnlocked
              ? const SizedBox.shrink(key: ValueKey('unlocked'))
              : _LockedView(key: const ValueKey('locked'), state: lock),
        ),
      ],
    );
  }
}

class _LockedView extends ConsumerWidget {
  const _LockedView({super.key, required this.state});

  final VaultLockState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final busy = state.status == VaultLockStatus.authenticating;

    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.face_unlock_outlined,
                    size: 48,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Vault is locked',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                state.message ?? 'Use Face ID to see your notes.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: state.message == null ? null : scheme.error,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : ref.read(vaultLockProvider.notifier).unlock,
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
