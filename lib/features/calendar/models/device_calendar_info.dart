/// One calendar on this phone (iCloud, a spouse's shared iCloud calendar,
/// Exchange, Holidays...), as listed by EventKit. Plugin-agnostic so the
/// picker screen and its tests don't depend on `device_calendar_plus`.
class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    this.colorHex,
    this.accountName,
    this.readOnly = false,
  });

  final String id;
  final String name;

  /// `#RRGGBB`, as set in the iOS Calendar app.
  final String? colorHex;

  /// The account the calendar lives under, e.g. "iCloud" -- used to group the
  /// picker. A calendar shared with you sits under your own iCloud account.
  final String? accountName;

  final bool readOnly;

  static final _offByDefault = RegExp(
    // English and German names, as iOS shows them on a German phone
    // (Deutsche Feiertage, Geburtstage, Siri-Vorschläge).
    r'holiday|birthday|siri suggestion|found in|feiertag|geburtstag|siri-vorschl',
    caseSensitive: false,
  );

  /// Holidays, Birthdays and Siri Suggestions would flood a family calendar,
  /// so they start switched off until the user turns them on.
  bool get isExcludedByDefault => _offByDefault.hasMatch(name);
}
