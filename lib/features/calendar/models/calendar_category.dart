import 'dart:ui' show Color;

/// What an event *is* to the family, which decides its colour everywhere:
/// each phone calendar is assigned one of the first three in the calendar
/// picker, and anything created inside Butlu is [butlu].
enum CalendarCategory {
  myOffice('My office', Color(0xFF0A84FF)), // iOS system blue.
  partnerOffice("Wife's office", Color(0xFFFF9F0A)), // iOS system orange.
  family('Family (famJam)', Color(0xFFBF5AF2)), // iOS system purple.
  butlu('Added in Butlu', Color(0xFF30D158)); // iOS system green.

  const CalendarCategory(this.label, this.color);

  final String label;
  final Color color;

  /// The roles a phone calendar can be given in the picker.
  static const assignable = [myOffice, partnerOffice, family];
}
