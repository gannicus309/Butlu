import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_category.dart';
import '../models/device_calendar_info.dart';

/// Loaded in main() before the app starts and overridden there, so the
/// saved calendar choices are known synchronously -- otherwise the Calendar
/// tab's first sync would run with the defaults before they'd loaded, and
/// remove (then a moment later restore) every event of a calendar the user
/// had switched on.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

/// Which of this phone's calendars are switched *off* for import, saved per
/// phone (it's about this phone's calendars, not shared family data).
///
/// State is null until the user first changes anything in the picker; until
/// then [DeviceCalendarInfo.isExcludedByDefault] decides. Once they do, the
/// full exclusion set is saved explicitly, so calendars added to the phone
/// later are imported unless switched off.
class CalendarSelectionController extends StateNotifier<Set<String>?> {
  CalendarSelectionController(this._prefs)
    : super(_prefs.getStringList(_key)?.toSet());

  static const _key = 'calendar.excludedIds';

  final SharedPreferences _prefs;

  bool isIncluded(DeviceCalendarInfo calendar) {
    final excluded = state;
    return excluded == null
        ? !calendar.isExcludedByDefault
        : !excluded.contains(calendar.id);
  }

  Future<void> setIncluded(
    DeviceCalendarInfo calendar,
    bool included,
    List<DeviceCalendarInfo> allCalendars,
  ) async {
    final excluded = {
      ...state ??
          {
            for (final c in allCalendars)
              if (c.isExcludedByDefault) c.id,
          },
    };
    included ? excluded.remove(calendar.id) : excluded.add(calendar.id);
    state = excluded;
    await _prefs.setStringList(_key, excluded.toList());
  }
}

final calendarSelectionProvider =
    StateNotifierProvider<CalendarSelectionController, Set<String>?>(
      (ref) =>
          CalendarSelectionController(ref.watch(sharedPreferencesProvider)),
    );

/// Which colour role (My office / Wife's office / Family) each phone calendar
/// has, saved per phone. Calendars not in the map count as Family.
class CalendarRolesController
    extends StateNotifier<Map<String, CalendarCategory>> {
  CalendarRolesController(this._prefs) : super(_read(_prefs));

  static const _key = 'calendar.roles';

  final SharedPreferences _prefs;

  static Map<String, CalendarCategory> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const {};
    final byName = CalendarCategory.values.asNameMap();
    return {
      for (final entry in (jsonDecode(raw) as Map<String, dynamic>).entries)
        entry.key: ?byName[entry.value],
    };
  }

  CalendarCategory roleOf(DeviceCalendarInfo calendar) =>
      state[calendar.id] ?? CalendarCategory.family;

  Future<void> setRole(
    DeviceCalendarInfo calendar,
    CalendarCategory category,
  ) async {
    state = {...state, calendar.id: category};
    await _prefs.setString(
      _key,
      jsonEncode({for (final e in state.entries) e.key: e.value.name}),
    );
  }
}

final calendarRolesProvider =
    StateNotifierProvider<
      CalendarRolesController,
      Map<String, CalendarCategory>
    >((ref) => CalendarRolesController(ref.watch(sharedPreferencesProvider)));
