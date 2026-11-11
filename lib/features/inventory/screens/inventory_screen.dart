import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../services/pack_scanner.dart';
import '../../../shared/widgets/account_avatar_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../../grocery/models/catalog.dart';
import '../../grocery/models/shopping_item.dart';
import '../../grocery/providers/grocery_providers.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../widgets/inventory_sheets.dart';
import '../widgets/inventory_tile.dart';

/// What's in the fridge, freezer and pantry, and when it goes off.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  /// Null shows everything.
  StorageLocation? _filter;

  static const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 140,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
  );

  @override
  void initState() {
    super.initState();
    // Brings over anything from the old Grocery tab's expiry list.
    ref.read(inventoryRepositoryProvider).importLegacyExpiryList();
  }

  String? get _uid => ref.read(authStateProvider).value?.uid;

  Future<void> _putAway(List<GroceryHistoryEntry> entries) async {
    final choices = await showPutAwaySheet(context, entries);
    final uid = _uid;
    if (choices == null || uid == null) return;
    final repo = ref.read(inventoryRepositoryProvider);
    await repo.addAll([
      for (final c in choices)
        if (c.include)
          InventoryItem(
            id: '',
            name: c.entry.item.name,
            emoji: c.entry.item.emoji,
            category: c.entry.item.category,
            storage: c.storage,
            catalogId: c.entry.item.catalogItem?.id,
            spec: c.entry.item.spec,
            expiresAt: c.expiresAt,
          ),
    ], uid: uid);
    await repo.markPutAway(choices.map((c) => c.entry.item.id));
    HapticFeedback.mediumImpact();
  }

  /// The + button: photo of the pack (the usual way) or typing it in.
  Future<void> _add() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              subtitle: const Text('Reads what it is and its date'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              onTap: () => Navigator.pop(context, 'library'),
            ),
            ListTile(
              leading: const Icon(Icons.keyboard_outlined),
              title: const Text('Type it in'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'camera':
        await _scan(fromLibrary: false);
      case 'library':
        await _scan(fromLibrary: true);
      case 'manual':
        await _addManually();
    }
  }

  void _say(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 6),
          content: Text(text),
          action: action,
        ),
      );
  }

  /// Photo → item, added straight away; the snackbar offers to fix it.
  Future<void> _scan({required bool fromLibrary}) async {
    var reading = false;
    final result = await scanPack(
      fromLibrary: fromLibrary,
      onPhotoTaken: () {
        if (!mounted) return;
        reading = true;
        showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(child: Text('Reading the pack…')),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (reading) Navigator.of(context, rootNavigator: true).pop();
    final uid = _uid;
    switch (result) {
      case null:
        return;
      case PackFailed(:final message):
        _say(message);
      case PackUnknown(:final seen):
        _say(
          seen.isEmpty
              ? "Couldn't make it out. Try closer, with more light."
              : "Couldn't tell what this is. Read: ${seen.take(4).join(' · ')}",
          action: SnackBarAction(label: 'Type it', onPressed: _addManually),
        );
      case PackFound(:final scan):
        if (uid == null) return;
        final id = await ref
            .read(inventoryRepositoryProvider)
            .add(scan.item, uid: uid);
        HapticFeedback.mediumImpact();
        if (!mounted) return;
        final item = scan.item;
        final date = item.expiresAt == null
            ? ''
            : scan.dateRead
            ? ' · until ${DateFormat.MMMEd().format(item.expiresAt!)}'
            : ' · no date found, guessed '
                  '${DateFormat.MMMEd().format(item.expiresAt!)}';
        _say(
          '${item.emoji}  ${item.name} → ${item.storage.label}$date',
          action: SnackBarAction(
            label: 'Change',
            onPressed: () => _open(
              InventoryItem(
                id: id,
                name: item.name,
                emoji: item.emoji,
                category: item.category,
                storage: item.storage,
                catalogId: item.catalogId,
                spec: item.spec,
                expiresAt: item.expiresAt,
              ),
            ),
          ),
        );
    }
  }

  Future<void> _addManually() async {
    final picked = await showAddToInventorySheet(context);
    final uid = _uid;
    if (picked == null || uid == null) return;
    final catalog = picked is CatalogItem ? picked : null;
    final name = catalog?.name ?? (picked as String);
    final item = InventoryItem(
      id: '',
      name: name,
      emoji: catalog?.emoji ?? '🥫',
      category: catalog?.category ?? GroceryCategory.other,
      storage: defaultStorage(catalog),
      catalogId: catalog?.id,
      expiresAt: estimatedExpiry(catalog, from: DateTime.now()),
    );
    await ref.read(inventoryRepositoryProvider).addAll([item], uid: uid);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(
            '${item.emoji}  ${item.name} → ${item.storage.label}. '
            'Tap it to set the exact date.',
          ),
        ),
      );
  }

  Future<void> _open(InventoryItem item) async {
    final result = await showInventoryItemSheet(context, item);
    final repo = ref.read(inventoryRepositoryProvider);
    switch (result) {
      case ItemSaved(:final item):
        await repo.update(item);
      case ItemUsedUp(:final addToList):
        HapticFeedback.mediumImpact();
        await repo.remove(item.id);
        final uid = _uid;
        if (addToList && uid != null) {
          final catalog = kCatalogById[item.catalogId];
          await ref
              .read(shoppingRepositoryProvider)
              .add(
                catalog != null
                    ? ShoppingItem.fromCatalog(catalog)
                    : ShoppingItem.custom(item.name),
                uid: uid,
              );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              persist: false,
              content: Text(
                addToList
                    ? '${item.emoji}  ${item.name} used up and added to the '
                          'shopping list'
                    : '${item.emoji}  ${item.name} used up',
              ),
            ),
          );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);
    final awaiting = ref.watch(awaitingPutAwayProvider);
    final all = itemsAsync.value ?? const <InventoryItem>[];
    final items = _filter == null
        ? all
        : all.where((i) => i.storage == _filter).toList();
    final soon = [
      for (final i in items)
        if ((i.daysLeft() ?? 99) <= 2) i,
    ];
    final rest = [
      for (final i in items)
        if ((i.daysLeft() ?? 99) > 2) i,
    ];

    Widget grid(List<InventoryItem> list) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: _grid,
        delegate: SliverChildListDelegate([
          for (final i in list)
            InventoryTile(key: ValueKey(i.id), item: i, onTap: () => _open(i)),
        ]),
      ),
    );

    Widget header(String text) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: const [AccountAvatarButton()],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'inventory-add',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          if (awaiting.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Text('🛍️', style: TextStyle(fontSize: 28)),
                    title: Text(
                      'Put away ${awaiting.length} '
                      'item${awaiting.length == 1 ? '' : 's'} you just bought',
                    ),
                    subtitle: const Text('Places and dates are filled in'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _putAway(awaiting),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  for (final s in <StorageLocation?>[
                    null,
                    StorageLocation.fridge,
                    StorageLocation.freezer,
                    StorageLocation.pantry,
                    StorageLocation.household,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          s == null
                              ? 'All · ${all.length}'
                              : '${s.emoji} ${s.label} · '
                                    '${all.where((i) => i.storage == s).length}',
                        ),
                        selected: _filter == s,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _filter = s);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (itemsAsync.isLoading && all.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.kitchen_outlined,
                message: awaiting.isNotEmpty
                    ? 'Put away your shopping to fill this up'
                    : 'Nothing here yet.\nTick things off your shopping list, '
                          'or tap + to add.',
              ),
            )
          else ...[
            if (soon.isNotEmpty) ...[header('Use soon'), grid(soon)],
            if (rest.isNotEmpty) ...[
              header(soon.isEmpty ? 'Everything' : 'Later'),
              grid(rest),
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
