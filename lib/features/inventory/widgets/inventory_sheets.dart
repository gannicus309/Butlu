import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../services/expiry_scanner.dart';
import '../../grocery/models/catalog.dart';
import '../../grocery/models/shopping_item.dart';
import '../models/inventory_item.dart';
import 'inventory_tile.dart';

/// What the user chose for one inventory item in [showInventoryItemSheet].
sealed class ItemSheetResult {}

class ItemSaved extends ItemSheetResult {
  ItemSaved(this.item);
  final InventoryItem item;
}

/// Removed without counting as used up -- added by mistake, or thrown
/// out.
class ItemDeleted extends ItemSheetResult {}

class ItemUsedUp extends ItemSheetResult {
  ItemUsedUp({required this.addToList});

  /// Also put it back on the shopping list.
  final bool addToList;
}

/// Photographs the pack and returns the date read off it, telling the user
/// via a snackbar when it couldn't. Null if nothing was found or they
/// backed out.
Future<DateTime?> scanDate(
  BuildContext context, {
  bool fromLibrary = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(persist: false, content: Text(text)));
  final result = await scanExpiryDate(fromLibrary: fromLibrary);
  switch (result) {
    case ScanFound(:final date):
      HapticFeedback.mediumImpact();
      say('Found ${DateFormat.yMMMd().format(date)}');
      return date;
    case ScanNoDate(:final text):
      say(
        text.isEmpty
            ? "Couldn't read any text. Try closer, with more light."
            : "No date found in: ${text.take(4).join(' · ')}",
      );
      return null;
    case ScanFailed(:final message):
      say(message);
      return null;
    case null:
      return null;
  }
}

/// The camera button next to a date. Long-press reads a photo already in
/// the library instead.
class ScanDateButton extends StatefulWidget {
  const ScanDateButton({super.key, required this.onDate});

  final ValueChanged<DateTime> onDate;

  @override
  State<ScanDateButton> createState() => _ScanDateButtonState();
}

class _ScanDateButtonState extends State<ScanDateButton> {
  bool _busy = false;

  Future<void> _scan({bool fromLibrary = false}) async {
    setState(() => _busy = true);
    final d = await scanDate(context, fromLibrary: fromLibrary);
    if (mounted) setState(() => _busy = false);
    if (d != null) widget.onDate(d);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: _busy ? null : () => _scan(fromLibrary: true),
    child: IconButton(
      tooltip: 'Scan date on pack (hold to pick a photo)',
      onPressed: _busy ? null : _scan,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.document_scanner_outlined),
    ),
  );
}

Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: now.subtract(const Duration(days: 365)),
    lastDate: now.add(const Duration(days: 365 * 5)),
    helpText: 'Use by / best before',
  );
}

class _StorageChips extends StatelessWidget {
  const _StorageChips({required this.value, required this.onChanged});

  final StorageLocation value;
  final ValueChanged<StorageLocation> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final s in StorageLocation.values)
        ChoiceChip(
          label: Text('${s.emoji} ${s.label}'),
          selected: s == value,
          onSelected: (_) => onChanged(s),
        ),
    ],
  );
}

/// Tap on an inventory tile: move it, change its date, or use it up.
Future<ItemSheetResult?> showInventoryItemSheet(
  BuildContext context,
  InventoryItem item,
) {
  var storage = item.storage;
  var expiresAt = item.expiresAt;
  final spec = TextEditingController(text: item.spec);
  final name = TextEditingController(text: item.name);
  final today = DateTime.now();
  final base = DateTime(today.year, today.month, today.day);

  return showModalBottomSheet<ItemSheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final days = expiresAt == null
            ? null
            : DateTime(
                expiresAt!.year,
                expiresAt!.month,
                expiresAt!.day,
              ).difference(base).inDays;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(),
                  suffixIcon: const Icon(Icons.edit_outlined, size: 18),
                  border: InputBorder.none,
                  hintText: 'Name',
                ),
              ),
              const SizedBox(height: 16),
              _StorageChips(
                value: storage,
                onChanged: (s) => setState(() => storage = s),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: expiryColor(days),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      expiresAt == null
                          ? 'No date'
                          : 'Use by ${DateFormat.MMMEd().format(expiresAt!)}',
                      style: TextStyle(
                        color: days == null ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ScanDateButton(onDate: (d) => setState(() => expiresAt = d)),
                  TextButton(
                    onPressed: () async {
                      final d = await _pickDate(context, expiresAt);
                      if (d != null) setState(() => expiresAt = d);
                    },
                    child: const Text('Pick date'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final (label, add) in const [
                    ('+1 day', 1),
                    ('+3 days', 3),
                    ('+1 week', 7),
                    ('+1 month', 30),
                  ])
                    ActionChip(
                      label: Text(label),
                      onPressed: () => setState(
                        () => expiresAt = (expiresAt ?? base).add(
                          Duration(days: add),
                        ),
                      ),
                    ),
                  ActionChip(
                    label: const Text('No date'),
                    onPressed: () => setState(() => expiresAt = null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: spec,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'e.g. opened, half left, 2 packs',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8710A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, ItemUsedUp(addToList: false)),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Used up'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF199E70),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, ItemUsedUp(addToList: true)),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Used up + buy'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => Navigator.pop(context, ItemDeleted()),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        ItemSaved(
                          item.copyWith(
                            name: name.text.trim().isEmpty
                                ? item.name
                                : name.text.trim(),
                            storage: storage,
                            expiresAt: expiresAt,
                            clearExpiry: expiresAt == null,
                            spec: spec.text.trim(),
                          ),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// One row of the put-away sheet.
class PutAwayChoice {
  PutAwayChoice(this.entry)
    : include =
          defaultStorage(entry.item.catalogItem) != StorageLocation.household,
      storage = defaultStorage(entry.item.catalogItem),
      expiresAt = estimatedExpiry(
        entry.item.catalogItem,
        from: entry.lastBoughtAt ?? DateTime.now(),
      );

  final GroceryHistoryEntry entry;
  bool include;
  StorageLocation storage;
  DateTime? expiresAt;
}

/// After shopping: everything just ticked off, each with a suggested place
/// and use-by date, to confirm in one tap. Returns the choices, or null if
/// dismissed. Household items start unticked -- few people track those.
Future<List<PutAwayChoice>?> showPutAwaySheet(
  BuildContext context,
  List<GroceryHistoryEntry> entries,
) {
  final choices = [for (final e in entries) PutAwayChoice(e)];
  return showModalBottomSheet<List<PutAwayChoice>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final count = choices.where((c) => c.include).length;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    'Put away',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Use-by dates are estimates. Tap one to set the date on '
                    'the pack.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in choices)
                        _PutAwayRow(
                          choice: c,
                          onChanged: () => setState(() {}),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          for (final c in choices) {
                            c.include = false;
                          }
                          Navigator.pop(context, choices);
                        },
                        child: const Text('Skip all'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context, choices),
                        icon: const Icon(Icons.check),
                        label: Text(count == 0 ? 'Done' : 'Put away $count'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _PutAwayRow extends StatelessWidget {
  const _PutAwayRow({required this.choice, required this.onChanged});

  final PutAwayChoice choice;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final item = choice.entry.item;
    final theme = Theme.of(context);
    final next = StorageLocation
        .values[(choice.storage.index + 1) % StorageLocation.values.length];
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: choice.include ? 1 : 0.45,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 12),
        leading: Checkbox(
          value: choice.include,
          onChanged: (v) {
            choice.include = v ?? false;
            onChanged();
          },
        ),
        title: Text('${item.emoji}  ${item.name}'),
        subtitle: Wrap(
          spacing: 6,
          children: [
            ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text('${choice.storage.emoji} ${choice.storage.label}'),
              tooltip: 'Tap for ${next.label}',
              onPressed: () {
                choice.storage = next;
                onChanged();
              },
            ),
            ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text(
                choice.expiresAt == null
                    ? 'No date'
                    : DateFormat.MMMd().format(choice.expiresAt!),
              ),
              avatar: Icon(
                Icons.event,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () async {
                final d = await _pickDate(context, choice.expiresAt);
                if (d != null) {
                  choice.expiresAt = d;
                  onChanged();
                }
              },
            ),
          ],
        ),
        trailing: ScanDateButton(
          onDate: (d) {
            choice.expiresAt = d;
            choice.include = true;
            onChanged();
          },
        ),
      ),
    );
  }
}

/// The + button: find an item and add it straight in with its usual place
/// and an estimated date. Returns the catalog item or typed name chosen.
Future<Object?> showAddToInventorySheet(BuildContext context) {
  final query = ValueNotifier('');
  return showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'What did you put away?',
              ),
              onChanged: (v) => query.value = v,
              onSubmitted: (v) {
                final t = v.trim();
                if (t.isEmpty) return;
                final m = searchCatalog(t);
                Navigator.pop(context, m.isNotEmpty ? m.first : t);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: query,
                builder: (context, q, _) {
                  final results = q.trim().isEmpty
                      ? kCatalog
                      : searchCatalog(q);
                  return ListView(
                    children: [
                      if (q.trim().isNotEmpty && results.isEmpty)
                        ListTile(
                          leading: const Text(
                            '➕',
                            style: TextStyle(fontSize: 24),
                          ),
                          title: Text('Add "${q.trim()}"'),
                          onTap: () => Navigator.pop(context, q.trim()),
                        ),
                      for (final c in results)
                        ListTile(
                          leading: Text(
                            c.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(c.name),
                          subtitle: Text(defaultStorage(c).label),
                          onTap: () => Navigator.pop(context, c),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
