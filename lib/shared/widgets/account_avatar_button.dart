import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';

/// Top-right of each top-level tab's AppBar: Ask Gemini (✨) and the
/// account picture. Both open full screen on the root navigator, above the
/// bottom tab bar.
class AccountAvatarButton extends ConsumerWidget {
  const AccountAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final initial =
        (user?.displayName?.isNotEmpty == true
                ? user!.displayName![0]
                : user?.email?[0] ?? '?')
            .toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Ask Gemini',
          onPressed: () => context.push('/ask'),
          icon: const Icon(Icons.auto_awesome),
        ),
        _avatar(context, user, initial),
      ],
    );
  }

  Widget _avatar(BuildContext context, User? user, String initial) {
    return IconButton(
      onPressed: () => context.push('/account'),
      icon: CircleAvatar(
        radius: 16,
        backgroundImage: user?.photoURL != null
            ? NetworkImage(user!.photoURL!)
            : null,
        child: user?.photoURL == null
            ? Text(initial, style: const TextStyle(fontSize: 14))
            : null,
      ),
    );
  }
}
