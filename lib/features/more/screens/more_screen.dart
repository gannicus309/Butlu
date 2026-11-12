import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/account_avatar_button.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        actions: const [AccountAvatarButton()],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Bills & subscriptions'),
            onTap: () => context.push('/more/bills'),
          ),
          ListTile(
            leading: const Icon(Icons.pin_drop_outlined),
            title: const Text("Who's got pickup"),
            onTap: () => context.push('/more/pickup'),
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu_outlined),
            title: const Text('Meal planning'),
            onTap: () => context.push('/more/meals'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Ask Gemini'),
            onTap: () => context.push('/ask'),
          ),
          ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: const Text('Family notes'),
            subtitle: const Text('What Gemini should know about you'),
            onTap: () => context.push('/more/notes'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Vault'),
            subtitle: const Text('Private notes, behind Face ID'),
            onTap: () => context.push('/more/vault'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Butlu'),
            subtitle: const Text('Version, build and connections'),
            onTap: () => context.push('/more/about'),
          ),
        ],
      ),
    );
  }
}
