import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/calendar_providers.dart';
import '../widgets/event_list_tile.dart';

class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsForDayProvider(date));

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.yMMMMEEEEd().format(date))),
      body: events.isEmpty
          ? Center(
              child: Text(
                'No events this day',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              itemCount: events.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => EventListTile(event: events[index]),
            ),
    );
  }
}
