import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/account_avatar_button.dart';
import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../providers/grocery_providers.dart';

class GroceryScreen extends ConsumerWidget {
  const GroceryScreen({super.key});

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    DateTime expiryDate = DateTime.now().add(const Duration(days: 7));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New grocery item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Item name'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Expires ${DateFormat.yMMMd().format(expiryDate)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: expiryDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setState(() => expiryDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    if (confirmed != true || name.isEmpty) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    await ref.read(groceryRepositoryProvider).addItem(
          name: name,
          expiryDate: expiryDate,
          addedByUid: uid,
        );
  }

  Color _expiryColor(BuildContext context, int daysLeft) {
    if (daysLeft < 0) return Colors.redAccent;
    if (daysLeft <= 2) return Colors.orangeAccent;
    return Theme.of(context).textTheme.bodySmall!.color!;
  }

  String _expiryLabel(int daysLeft) {
    if (daysLeft < 0) return 'Expired ${-daysLeft}d ago';
    if (daysLeft == 0) return 'Expires today';
    if (daysLeft == 1) return 'Expires tomorrow';
    return 'Expires in $daysLeft days';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(groceryItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery'),
        actions: const [AccountAvatarButton()],
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No groceries tracked yet',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final daysLeft = item.daysUntilExpiry();
              return ListTile(
                title: Text(item.name),
                subtitle: Text(
                  _expiryLabel(daysLeft),
                  style: TextStyle(color: _expiryColor(context, daysLeft)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      ref.read(groceryRepositoryProvider).deleteItem(item.id),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Something went wrong: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addItem(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
