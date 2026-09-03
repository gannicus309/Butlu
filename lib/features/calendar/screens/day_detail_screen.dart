import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../models/calendar_event.dart';
import '../models/event_source.dart';
import '../providers/calendar_providers.dart';
import '../widgets/event_list_tile.dart';

class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({super.key, required this.date});

  final DateTime date;

  Future<void> _addEvent(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New event'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final startAt = DateTime(date.year, date.month, date.day, 9).toUtc();
    final nowUtc = DateTime.now().toUtc();
    final event = CalendarEvent(
      id: const Uuid().v4(),
      title: trimmed,
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
      timeZone: 'local',
      source: EventSource.butlu,
      createdByUid: uid,
      lastModifiedAt: nowUtc,
      lastModifiedBy: EventSource.butlu,
    );
    await ref.read(firestoreEventRepositoryProvider).upsert(event);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsForDayProvider(date));

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.yMMMMEEEEd().format(date))),
      body: events.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              message: 'No events this day',
            )
          : ListView.separated(
              itemCount: events.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => FadeSlideIn(
                delay: FadeSlideIn.staggerDelay(index),
                child: EventListTile(event: events[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEvent(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
