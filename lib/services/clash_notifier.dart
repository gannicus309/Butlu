import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/calendar/models/conflicts.dart';

/// Local notifications for calendar clashes, each clash notified once.
///
/// Runs whenever the app sees a new set of events (a sync on this phone, or
/// another family member's change arriving through Firestore). It can't wake
/// the app by itself: with the app closed, a clash is noticed the next time
/// it opens.
class ClashNotifier {
  ClashNotifier(this._prefs, {FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin;

  static const _seenKey = 'calendar.notifiedClashes';

  /// Enough to cover a month of clashes without the list growing forever.
  static const _maxRemembered = 500;

  /// More new clashes than this at once (e.g. the very first run) become one
  /// summary notification instead of a flood.
  static const _maxIndividual = 3;

  bool _ready = false;

  /// Sets up the app's notifications, clash and pantry alike: [onOpenDay]
  /// is called with the day when a clash notification is tapped, and
  /// [onOpenInventory] when a use-soon reminder is.
  Future<void> init({
    required void Function(DateTime day) onOpenDay,
    required VoidCallback onOpenInventory,
  }) async {
    if (kIsWeb) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload ?? '';
        if (payload == 'inventory') return onOpenInventory();
        final day = DateTime.tryParse(payload);
        if (day != null) onOpenDay(day);
      },
    );
    _ready = true;
  }

  /// Asks iOS for permission the first time; afterwards iOS answers from the
  /// user's earlier choice without showing anything.
  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true, badge: false);
  }

  Set<String> get _seen => (_prefs.getStringList(_seenKey) ?? const []).toSet();

  /// Records clashes as already known, so they're never notified -- e.g. one
  /// the user just confirmed with "Add anyway".
  Future<void> markSeen(Iterable<String> keys) async {
    final list = _prefs.getStringList(_seenKey) ?? <String>[];
    for (final k in keys) {
      if (!list.contains(k)) list.add(k);
    }
    final trimmed = list.length > _maxRemembered
        ? list.sublist(list.length - _maxRemembered)
        : list;
    await _prefs.setStringList(_seenKey, trimmed);
  }

  /// Notifies about the clashes in [conflicts] not notified before.
  Future<void> notifyNew(List<EventConflict> conflicts) async {
    if (!_ready) return;
    final seen = _seen;
    final fresh = [
      for (final c in conflicts)
        if (!seen.contains(c.key)) c,
    ];
    if (fresh.isEmpty) return;
    await markSeen(fresh.map((c) => c.key));

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
        threadIdentifier: 'calendar-clashes',
      ),
    );

    if (fresh.length > _maxIndividual) {
      final first = fresh.first.a.startAt.toLocal();
      await _plugin.show(
        id: 0,
        title: '${fresh.length} calendar clashes',
        body:
            'Overlapping plans in the coming weeks, starting '
            '${DateFormat.MMMEd().format(first)}. Tap to see the first.',
        notificationDetails: details,
        payload: _dayPayload(first),
      );
      return;
    }
    for (final c in fresh) {
      final start = c.b.startAt.isAfter(c.a.startAt)
          ? c.b.startAt.toLocal()
          : c.a.startAt.toLocal();
      await _plugin.show(
        id: c.key.hashCode & 0x7fffffff,
        title: 'Calendar clash · ${DateFormat.MMMEd().add_jm().format(start)}',
        body:
            '"${c.a.title}" (${c.a.effectiveCategory.label}) overlaps '
            '"${c.b.title}" (${c.b.effectiveCategory.label})',
        notificationDetails: details,
        payload: _dayPayload(start),
      );
    }
  }

  static String _dayPayload(DateTime local) =>
      DateFormat('yyyy-MM-dd').format(local);
}
