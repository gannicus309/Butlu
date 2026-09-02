import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';

/// Top-right account entry point, added to each top-level tab's AppBar
/// actions. Opens the full-screen Account page (profile, settings, sign out)
/// as a route pushed on the root navigator, above the bottom tab bar.
class AccountAvatarButton extends ConsumerWidget {
  const AccountAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final initial = (user?.displayName?.isNotEmpty == true
            ? user!.displayName![0]
            : user?.email?[0] ?? '?')
        .toUpperCase();

    return IconButton(
      onPressed: () => context.push('/account'),
      icon: CircleAvatar(
        radius: 16,
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        child: user?.photoURL == null
            ? Text(initial, style: const TextStyle(fontSize: 14))
            : null,
      ),
    );
  }
}
