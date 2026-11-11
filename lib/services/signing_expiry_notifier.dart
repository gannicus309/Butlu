import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Warns a day ahead that this build is about to stop opening.
///
/// Builds signed with a free Apple ID expire 7 days after they're made. The
/// Mac re-signs them automatically (tool/resign.sh), but only when it can
/// reach the phone -- so if it hasn't by the day before, this says so.
/// Re-planned on every launch, so a fresh build quietly replaces the
/// warning with one for its own, later date.
class SigningExpiryNotifier {
  SigningExpiryNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _channel = MethodChannel('butlu/signing');
  static const _id = 910000;

  /// Call after ExpiryNotifier.init, which sets up time zones.
  Future<void> schedule() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final DateTime expiresAt;
    try {
      final raw = await _channel.invokeMethod<String>('expiresAt');
      if (raw == null) return; // App Store build: never expires.
      expiresAt = DateTime.parse(raw).toLocal();
    } on Object {
      return;
    }
    await _plugin.cancel(id: _id);

    final now = DateTime.now();
    if (!expiresAt.isAfter(now)) return;
    final warnAt = expiresAt.subtract(const Duration(days: 1));
    final when = DateFormat('EEE HH:mm').format(expiresAt);
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
        threadIdentifier: 'butlu-signing',
      ),
    );
    const title = 'Butlu expires tomorrow';
    final body =
        'It stops opening $when. Open the MacBook on the same Wi-Fi with '
        'this phone unlocked so it can re-sign.';

    if (warnAt.isAfter(now)) {
      await _plugin.zonedSchedule(
        id: _id,
        scheduledDate: tz.TZDateTime.from(warnAt, tz.local),
        title: title,
        body: body,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } else {
      // Already inside the last day.
      await _plugin.show(
        id: _id,
        title: 'Butlu expires $when',
        body: body,
        notificationDetails: details,
      );
    }
  }
}
