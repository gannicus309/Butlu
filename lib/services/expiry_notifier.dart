import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../features/grocery/models/catalog.dart';
import '../features/inventory/models/inventory_item.dart';

/// Reminders, scheduled with iOS, that pantry items are about to go off --
/// so they arrive even when Butlu isn't running.
///
/// One notification per day, at 9:00 the morning before, listing whatever
/// expires the next day. Re-planned from scratch whenever the inventory
/// changes; iOS only keeps 64 pending notifications per app, so it plans 30
/// days ahead and no further.
class ExpiryNotifier {
  ExpiryNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Ids 900000..900029, one per day ahead; well clear of clash ids, which
  /// are hashes but only ever shown immediately, never left pending.
  static const _baseId = 900000;
  static const _days = 30;
  static const _hour = 9;

  bool _ready = false;
  String _lastPlan = '';

  /// Call after the notifications plugin itself has been initialised.
  Future<void> init() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Unknown zone name: fall back to UTC rather than not reminding.
    }
    _ready = true;
  }

  Future<void> reschedule(List<InventoryItem> items) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);

    // Items expiring on each of the next days; notified the morning before.
    final byDay = <int, List<InventoryItem>>{};
    for (final item in items) {
      final e = item.expiresAt;
      if (e == null || item.storage == StorageLocation.household) continue;
      final expiryDay = tz.TZDateTime(tz.local, e.year, e.month, e.day);
      final offset = expiryDay.difference(today).inDays - 1;
      if (offset < 0 || offset >= _days) continue;
      byDay.putIfAbsent(offset, () => []).add(item);
    }

    // Skip the work when nothing that matters changed (most snapshots).
    final plan = [
      for (final e in byDay.entries.toList()..sort((a, b) => a.key - b.key))
        '${e.key}:${e.value.map((i) => i.name).join(',')}',
    ].join('|');
    if (plan == _lastPlan) return;
    _lastPlan = plan;

    for (var d = 0; d < _days; d++) {
      await _plugin.cancel(id: _baseId + d);
    }
    for (final MapEntry(key: offset, value: due) in byDay.entries) {
      final at = today.add(Duration(days: offset, hours: _hour));
      if (!at.isAfter(now)) continue;
      final names = due.map((i) => '${i.emoji} ${i.name}').toList();
      await _plugin.zonedSchedule(
        id: _baseId + offset,
        scheduledDate: at,
        title: due.length == 1
            ? 'Use soon: ${due.single.name}'
            : 'Use soon: ${due.length} items',
        body: 'Going off tomorrow: ${names.join(', ')}',
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
            threadIdentifier: 'pantry-expiry',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'inventory',
      );
    }
  }
}
