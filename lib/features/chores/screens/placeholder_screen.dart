import 'package:flutter/material.dart';

import '../../../shared/widgets/account_avatar_button.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores'),
        actions: const [AccountAvatarButton()],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checklist_outlined, size: 48),
            const SizedBox(height: 12),
            Text('Coming soon', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
