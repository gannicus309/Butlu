import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/family_members_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Text(
                      (user?.displayName?.isNotEmpty == true
                              ? user!.displayName![0]
                              : user?.email?[0] ?? '?')
                          .toUpperCase(),
                      style: const TextStyle(fontSize: 28),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user?.displayName ?? 'Signed in',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (user?.email != null)
            Center(
              child: Text(
                user!.email!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 24),
          const _FamilySection(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            subtitle: const Text('Coming soon'),
            onTap: null,
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Sign out',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
    );
  }
}

final memberEmailsProvider = StreamProvider<List<String>>((ref) {
  final familyId = ref.watch(familyIdProvider);
  return FirebaseFirestore.instance
      .collection('families')
      .doc(familyId)
      .collection('members')
      .snapshots()
      .map((s) => [for (final d in s.docs) ?d.data()['email'] as String?]);
}, dependencies: [familyIdProvider]);

/// Who's in the family, who's invited, and inviting someone new.
class _FamilySection extends ConsumerWidget {
  const _FamilySection();

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite to family'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Their Google account email',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    final trimmed = email?.trim() ?? '';
    if (!trimmed.contains('@')) return;
    await ref
        .read(familyServiceProvider)
        .invite(ref.read(familyIdProvider), trimmed);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          persist: false,
          content: Text(
            'Invited $trimmed. They can join when they sign in to Butlu '
            'with that Google account.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final family = ref.watch(familyDocProvider).value ?? const {};
    final members = ref.watch(familyMembersProvider).value ?? const {};
    // Invites stay listed after someone joins; hide the ones already in.
    final memberEmails = {
      for (final e in ref.watch(memberEmailsProvider).value ?? const [])
        e.toLowerCase(),
    };
    final invited = [
      for (final e in (family['invitedEmails'] as List? ?? const [])) '$e',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            (family['name'] as String?) ?? 'Family',
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final name in members.values)
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(name),
            subtitle: const Text('Member'),
          ),
        for (final e in invited)
          if (!memberEmails.contains(e.toLowerCase()))
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(e),
              subtitle: const Text('Invited · joins when they sign in'),
            ),
        ListTile(
          leading: const Icon(Icons.person_add_alt),
          title: const Text('Invite by email'),
          onTap: () => _invite(context, ref),
        ),
      ],
    );
  }
}
