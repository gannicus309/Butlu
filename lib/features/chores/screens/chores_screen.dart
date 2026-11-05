import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/account_avatar_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../../auth/providers/family_members_provider.dart';
import '../models/chore_load.dart';
import '../models/chore.dart';
import '../providers/chore_providers.dart';
import '../widgets/chore_editor.dart';
import '../widgets/chore_row.dart';

enum _Filter { all, today, priority, repeating, special }

/// The family's to-dos, Apple Reminders-style: suggestions on top, then
/// Overdue / Today / Upcoming / Someday, each task coloured by kind.
class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    // Brings over anything from the old Chores tab.
    ref.read(choreRepositoryProvider).importOldTasks();
  }

  String? get _uid => ref.read(authStateProvider).value?.uid;

  List<String> _knownTags(List<Chore> chores) {
    final tags = <String>{
      for (final c in chores) ...c.tags,
      for (final s in kChoreSuggestions) ...s.tags,
    };
    return tags.toList()..sort();
  }

  Future<void> _edit(Chore chore, List<Chore> all) async {
    final result = await showChoreEditor(
      context,
      chore: chore,
      assignees: ref.read(assigneeOptionsProvider),
      knownTags: _knownTags(all),
    );
    final repo = ref.read(choreRepositoryProvider);
    final uid = _uid;
    switch (result) {
      case ChoreSaved(:final chore):
        if (uid != null) await repo.save(chore, uid: uid);
      case ChoreDeleted():
        await repo.delete(chore.id);
      case null:
        break;
    }
  }

  void _fromSuggestion(ChoreSuggestion s, List<Chore> all) {
    final n = DateTime.now();
    _edit(
      Chore(
        id: '',
        title: s.title,
        subtype: s.subtype,
        repeat: s.repeat,
        priority: s.priority,
        tags: s.tags,
        dueAt: DateTime(n.year, n.month, n.day),
      ),
      all,
    );
  }

  Future<void> _complete(Chore chore) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(choreRepositoryProvider);
    final now = DateTime.now();
    final uid = _uid;
    final me =
        ref.read(familyMembersProvider).value?[uid] ??
        ref.read(authStateProvider).value?.displayName ??
        'Me';
    final done = await repo.complete(chore, now: now, doneBy: me);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 3),
          content: Text(
            chore.repeat == ChoreRepeat.none
                ? '“${chore.title}” done'
                : '“${chore.title}” done · next on '
                      '${DateFormat.MMMEd().format(nextDue(chore, now))}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.undoComplete(done),
          ),
        ),
      );
  }

  bool _matches(Chore c, DateTime now) => switch (_filter) {
    _Filter.all => true,
    _Filter.today => c.isDueToday(now) || c.isOverdue(now),
    _Filter.priority => c.kind == ChoreKind.priority,
    _Filter.repeating => c.kind == ChoreKind.repeating,
    _Filter.special => c.kind == ChoreKind.special,
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(choresProvider);
    final all = async.value ?? const <Chore>[];
    final now = DateTime.now();
    final shown = [
      for (final c in all)
        if (_matches(c, now)) c,
    ];
    final existing = {for (final c in all) c.title.toLowerCase()};
    final suggestions = [
      for (final s in kChoreSuggestions)
        if (!existing.contains(s.title.toLowerCase())) s,
    ];

    final sections = <(String, Color?, List<Chore>)>[
      (
        'Overdue',
        ChoreKind.priority.color,
        [
          for (final c in shown)
            if (c.isOverdue(now)) c,
        ],
      ),
      (
        'Today',
        null,
        [
          for (final c in shown)
            if (c.isDueToday(now) && !c.isOverdue(now)) c,
        ],
      ),
      (
        'Upcoming',
        null,
        [
          for (final c in shown)
            if (c.dueAt != null && !c.isDueToday(now) && !c.isOverdue(now)) c,
        ],
      ),
      (
        'Someday',
        null,
        [
          for (final c in shown)
            if (c.dueAt == null) c,
        ],
      ),
    ];

    int count(_Filter f) {
      final saved = _filter;
      _filter = f;
      final n = all.where((c) => _matches(c, now)).length;
      _filter = saved;
      return n;
    }

    var index = 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores'),
        actions: [
          IconButton(
            tooltip: 'Chore load',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => context.go('/chores/load'),
          ),
          const AccountAvatarButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'chores-add',
        onPressed: () => _edit(const Chore(id: '', title: ''), all),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: CustomScrollView(
        slivers: [
          if (suggestions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Text(
                  'Suggestions',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          if (suggestions.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final s in suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: Text(s.subtype.emoji),
                          label: Text(s.title),
                          side: BorderSide(
                            color:
                                (s.priority
                                        ? ChoreKind.priority
                                        : s.repeat != ChoreRepeat.none
                                        ? ChoreKind.repeating
                                        : ChoreKind.special)
                                    .color
                                    .withValues(alpha: 0.6),
                          ),
                          onPressed: () => _fromSuggestion(s, all),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  for (final (f, label, color) in [
                    (_Filter.all, 'All', null),
                    (_Filter.today, 'Today', null),
                    (
                      _Filter.priority,
                      ChoreKind.priority.label,
                      ChoreKind.priority.color,
                    ),
                    (
                      _Filter.repeating,
                      ChoreKind.repeating.label,
                      ChoreKind.repeating.color,
                    ),
                    (
                      _Filter.special,
                      ChoreKind.special.label,
                      ChoreKind.special.color,
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: color == null
                            ? null
                            : CircleAvatar(radius: 5, backgroundColor: color),
                        label: Text('$label · ${count(f)}'),
                        selected: _filter == f,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _filter = f);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (async.isLoading && all.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (shown.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.task_alt,
                message: 'Nothing to do here.\nTap a suggestion or New task.',
              ),
            )
          else
            for (final (title, color, list) in sections)
              if (list.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                    child: Text(
                      '$title · ${list.length}',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: color),
                    ),
                  ),
                ),
                SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, i) =>
                      const Divider(height: 1, indent: 52),
                  itemBuilder: (context, i) => FadeSlideIn(
                    key: ValueKey(list[i].id),
                    delay: FadeSlideIn.staggerDelay(index++),
                    child: ChoreRow(
                      chore: list[i],
                      onComplete: () => _complete(list[i]),
                      onOpen: () => _edit(list[i], all),
                    ),
                  ),
                ),
              ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
