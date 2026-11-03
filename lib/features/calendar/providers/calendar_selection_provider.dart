import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_calendar_info.dart';

/// Which of this phone's calendars are switched *off* for import, saved per
/// phone (it's about this phone's calendars, not shared family data).
///
/// State is null until the user first changes anything in the picker; until
/// then [DeviceCalendarInfo.isExcludedByDefault] decides. Once they do, the
/// full exclusion set is saved explicitly, so calendars added to the phone
/// later are imported unless switched off.
class CalendarSelectionController extends StateNotifier<Set<String>?> {
  CalendarSelectionController() : super(null) {
    _load();
  }

  static const _key = 'calendar.excludedIds';

  Future<void> _load() async {
    final saved = (await SharedPreferences.getInstance()).getStringList(_key);
    if (saved != null && mounted) state = saved.toSet();
  }

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
    await (await SharedPreferences.getInstance()).setStringList(
      _key,
      excluded.toList(),
    );
  }
}

final calendarSelectionProvider =
    StateNotifierProvider<CalendarSelectionController, Set<String>?>(
      (ref) => CalendarSelectionController(),
    );
