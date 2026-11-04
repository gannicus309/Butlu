import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/account_avatar_button.dart';
import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../models/catalog.dart';
import '../models/shopping_item.dart';
import '../providers/grocery_providers.dart';
import '../widgets/grocery_tile.dart';

/// The shared shopping list, Bring!-style: what's to buy as red tiles on
/// top, then recently used items and the whole catalog as tiles to tap onto
/// the list, with an "I need ..." search at the bottom.
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  static const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    // Three to a row on a phone, like Bring!.
    maxCrossAxisExtent: 140,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 1,
  );

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String? get _uid => ref.read(authStateProvider).value?.uid;

  Future<void> _add(ShoppingItem item) async {
    final uid = _uid;
    if (uid == null) return;
    HapticFeedback.lightImpact();
    await ref.read(shoppingRepositoryProvider).add(item, uid: uid);
  }

  Future<void> _bought(ShoppingItem item) async {
    HapticFeedback.mediumImpact();
    await ref.read(shoppingRepositoryProvider).markBought(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.emoji}  ${item.name} ticked off'),
          duration: const Duration(seconds: 3),
          // A snackbar with an action stays up until tapped by default; this
          // one should just fade away like Bring!'s.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              final uid = _uid;
              if (uid != null) {
                ref.read(shoppingRepositoryProvider).undoBought(item, uid: uid);
              }
            },
          ),
        ),
      );
  }

  /// Drops an item from "Recently used" -- for typos and one-offs.
  Future<void> _forget(ShoppingItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Forget ${item.name}?'),
        content: const Text('It will no longer show under Recently used.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(shoppingRepositoryProvider).forget(item.id);
    }
  }

  Future<void> _remove(ShoppingItem item) async {
    HapticFeedback.selectionClick();
    await ref.read(shoppingRepositoryProvider).remove(item.id);
  }

  /// Search box submit: the best catalog match, or the typed text as a new
  /// item of its own.
  Future<void> _addFromSearch() async {
    final text = _search.text.trim();
    if (text.isEmpty) return;
    final matches = searchCatalog(text);
    await _add(
      matches.isNotEmpty
          ? ShoppingItem.fromCatalog(matches.first)
          : ShoppingItem.custom(text),
    );
    _search.clear();
    setState(() => _query = '');
  }

  Future<void> _editItem(ShoppingItem item) async {
    final controller = TextEditingController(text: item.spec);
    final result = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
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
            Text(
              '${item.emoji}  ${item.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText: 'e.g. 2 L, organic, the big pack',
              ),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, '\u0000remove'),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove from list'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    if (result == '\u0000remove') {
      await _remove(item);
    } else {
      await ref.read(shoppingRepositoryProvider).setSpec(item.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(shoppingListProvider).value ?? const [];
    final history = ref.watch(groceryHistoryProvider).value ?? const [];
    final onList = {for (final i in list) i.id: i};

    void toggle(ShoppingItem item) {
      final existing = onList[item.id];
      existing == null ? _add(item) : _remove(existing);
    }

    Widget catalogTile(CatalogItem c) {
      final listed = onList[c.id];
      return GroceryTile(
        key: ValueKey('c-${c.id}'),
        emoji: c.emoji,
        name: c.name,
        spec: listed?.spec ?? '',
        onList: listed != null,
        onTap: () => toggle(ShoppingItem.fromCatalog(c)),
        onLongPress: listed == null ? null : () => _editItem(listed),
      );
    }

    final slivers = <Widget>[];
    if (_query.isNotEmpty) {
      final matches = searchCatalog(_query);
      final custom = ShoppingItem.custom(_query);
      final showCustom =
          !matches.any(
            (m) => m.name.toLowerCase() == _query.trim().toLowerCase(),
          ) &&
          !onList.containsKey(custom.id);
      slivers.addAll([
        _header(context, matches.isEmpty ? 'Not in the catalog' : 'Matches'),
        _gridOf([
          if (showCustom)
            GroceryTile(
              key: const ValueKey('custom'),
              emoji: '➕',
              name: 'Add "${_query.trim()}"',
              onList: false,
              onTap: () async {
                await _add(custom);
                _search.clear();
                setState(() => _query = '');
              },
            ),
          for (final c in matches) catalogTile(c),
        ]),
      ]);
    } else {
      slivers.addAll([
        _header(
          context,
          list.isEmpty ? 'Shopping list' : 'To buy · ${list.length}',
        ),
        if (list.isEmpty)
          SliverToBoxAdapter(child: _emptyList(context))
        else
          _gridOf([
            for (final item in list)
              GroceryTile(
                key: ValueKey('l-${item.id}'),
                emoji: item.emoji,
                name: item.name,
                spec: item.spec,
                onList: true,
                onTap: () => _bought(item),
                onLongPress: () => _editItem(item),
              ),
          ]),
      ]);
      final recent = [
        for (final h in history)
          if (!onList.containsKey(h.item.id)) h.item,
      ].take(12).toList();
      if (recent.isNotEmpty) {
        slivers.addAll([
          _header(context, 'Recently used'),
          _gridOf([
            for (final item in recent)
              GroceryTile(
                key: ValueKey('r-${item.id}'),
                emoji: item.emoji,
                name: item.name,
                onList: false,
                onTap: () => _add(item),
                onLongPress: () => _forget(item),
              ),
          ]),
        ]);
      }
      for (final category in GroceryCategory.values) {
        final items = kCatalog.where((c) => c.category == category).toList();
        if (items.isEmpty) continue;
        slivers.addAll([
          _header(context, category.label, color: Color(category.colorValue)),
          _gridOf([for (final c in items) catalogTile(c)]),
        ]);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery'),
        actions: const [AccountAvatarButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _searchFocus.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  ...slivers,
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
          _searchBar(context),
        ],
      ),
    );
  }

  Widget _gridOf(List<Widget> tiles) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    sliver: SliverGrid(
      gridDelegate: _grid,
      delegate: SliverChildListDelegate(tiles),
    ),
  );

  Widget _header(BuildContext context, String text, {Color? color}) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              if (color != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(text, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );

  Widget _emptyList(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Text('🧺', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Nothing to buy. Tap any tile below to add it, '
                'or type in "I need …".',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _searchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (_) => _addFromSearch(),
                  decoration: InputDecoration(
                    hintText: 'I need …',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                heroTag: 'grocery-add',
                onPressed: _query.isEmpty
                    ? () => _searchFocus.requestFocus()
                    : _addFromSearch,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
