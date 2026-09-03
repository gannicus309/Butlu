import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../providers/bill_providers.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  Future<void> _addBill(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    bool autoPay = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New bill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (optional)'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Due ${DateFormat.yMMMd().format(dueDate)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setState(() => dueDate = picked);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-pay'),
                value: autoPay,
                onChanged: (value) => setState(() => autoPay = value),
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

    await ref.read(billRepositoryProvider).addBill(
          name: name,
          amount: double.tryParse(amountController.text.trim()),
          dueDate: dueDate,
          autoPay: autoPay,
          createdByUid: uid,
        );
  }

  Color _dueColor(BuildContext context, int daysLeft) {
    if (daysLeft < 0) return Colors.redAccent;
    if (daysLeft <= 3) return Colors.orangeAccent;
    return Theme.of(context).textTheme.bodySmall!.color!;
  }

  String _dueLabel(int daysLeft) {
    if (daysLeft < 0) return 'Overdue by ${-daysLeft}d';
    if (daysLeft == 0) return 'Due today';
    if (daysLeft == 1) return 'Due tomorrow';
    return 'Due in $daysLeft days';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bills & subscriptions')),
      body: billsAsync.when(
        data: (bills) {
          if (bills.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No bills tracked yet',
            );
          }
          return ListView.separated(
            itemCount: bills.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final bill = bills[index];
              final daysLeft = bill.daysUntilDue();
              return FadeSlideIn(
                delay: FadeSlideIn.staggerDelay(index),
                child: ListTile(
                  title: Text(bill.name),
                  subtitle: Text(
                    _dueLabel(daysLeft),
                    style: TextStyle(color: _dueColor(context, daysLeft)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (bill.amount != null)
                        Text(NumberFormat.simpleCurrency().format(bill.amount)),
                      if (bill.autoPay)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.autorenew, size: 18),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            ref.read(billRepositoryProvider).deleteBill(bill.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Something went wrong: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addBill(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
