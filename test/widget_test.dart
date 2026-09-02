import 'package:butlu/features/auth/providers/auth_providers.dart';
import 'package:butlu/features/calendar/data/firestore_event_repository.dart';
import 'package:butlu/features/calendar/models/calendar_event.dart';
import 'package:butlu/features/calendar/models/event_source.dart';
import 'package:butlu/features/calendar/providers/calendar_providers.dart';
import 'package:butlu/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed-content fake so the widget tests don't need a live Firebase
/// project -- ButluApp itself has no knowledge this isn't the real
/// Firestore-backed repository.
class _FakeFirestoreEventRepository implements FirestoreEventRepository {
  final List<CalendarEvent> events;
  _FakeFirestoreEventRepository(this.events);

  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(events);

  @override
  Future<List<CalendarEvent>> fetchAll() async => events;

  @override
  Future<CalendarEvent?> findByExternalId({
    required EventSource source,
    required String externalId,
  }) async =>
      null;

  @override
  Future<void> upsert(CalendarEvent event) async {}

  @override
  Future<void> softDelete(String eventId) async {}
}

List<CalendarEvent> _sampleEvents() {
  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day, 9, 30);
  return [
    CalendarEvent(
      id: 'sample-1',
      title: 'Pediatrician checkup',
      startAt: today,
      endAt: today.add(const Duration(minutes: 45)),
      timeZone: 'local',
      source: EventSource.outlook,
      createdByUid: 'sample-uid',
      lastModifiedAt: today,
      lastModifiedBy: EventSource.outlook,
    ),
  ];
}

void main() {
  Widget appWithFakeData() {
    return ProviderScope(
      overrides: [
        firestoreEventRepositoryProvider
            .overrideWithValue(_FakeFirestoreEventRepository(_sampleEvents())),
        // AccountAvatarButton reads this; without an override it hits real
        // FirebaseAuth, which was never initialized in a widget test.
        authStateProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const ButluApp(),
    );
  }

  testWidgets('shows the Calendar tab with all five nav destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(appWithFakeData());
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Grocery'), findsOneWidget);
    expect(find.text('Chores'), findsOneWidget);
    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('tapping a day with events opens its day-detail list',
      (WidgetTester tester) async {
    await tester.pumpWidget(appWithFakeData());
    await tester.pumpAndSettle();

    final today = DateTime.now().day.toString();
    await tester.tap(find.text(today).first);
    await tester.pumpAndSettle();

    expect(find.text('Pediatrician checkup'), findsOneWidget);
  });
}
