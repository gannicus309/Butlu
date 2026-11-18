import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Says "Butlu updated" the first time a new build runs -- a new version,
/// or the same one re-signed for another week.
///
/// The Mac starts Butlu in the background right after installing it
/// (tool/resign.sh), so this usually appears within seconds of the
/// update; otherwise it appears the next time Butlu is opened.
class UpdateNotifier {
  UpdateNotifier(this._prefs, {FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin;
  static const _channel = MethodChannel('butlu/signing');
  static const _key = 'update.lastAnnounced';
  static const _id = 920000;

  /// Call after the notifications plugin is initialised.
  Future<void> announceIfNew() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final Map<String, Object?> info;
    try {
      info =
          await _channel.invokeMapMethod<String, Object?>('appInfo') ??
          const {};
    } on Object {
      return;
    }
    final version = '${info['version'] ?? '?'}';
    final build = '${info['build'] ?? '?'}';
    final expiresRaw = info['expiresAt'];
    final current = '$version+$build|$expiresRaw';
    final previous = _prefs.getString(_key);
    if (previous == current) return;
    await _prefs.setString(_key, current);
    // The very first run on a phone has nothing to compare with.
    if (previous == null) return;

    final expires = expiresRaw is String
        ? DateTime.tryParse(expiresRaw)?.toLocal()
        : null;
    final until = expires == null
        ? ''
        : ' Works until ${DateFormat('EEE d MMM, HH:mm').format(expires)}.';
    final sameVersion = previous.startsWith('$version+$build|');
    await _plugin.show(
      id: _id,
      title: sameVersion ? 'Butlu renewed' : 'Butlu updated',
      body: sameVersion
          ? 'Re-signed for another week.$until'
          : 'Now on version $version (build $build).$until',
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          threadIdentifier: 'butlu-update',
        ),
      ),
    );
  }
}
