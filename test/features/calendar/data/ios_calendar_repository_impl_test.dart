import 'package:butlu/features/calendar/data/ios_calendar_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ids from subscribed calendars become valid Firestore document ids', () {
    final id = IosCalendarRepositoryImpl.safeDocumentId('abc/def/ghi');
    expect(id, isNot(contains('/')));
  });

  test('ordinary EventKit ids are left unchanged', () {
    const ios = 'D51CF18D-717B-42CB:5e73d9c6@1786140000000';
    expect(IosCalendarRepositoryImpl.safeDocumentId(ios), ios);
  });

  test('different ids never map to the same document id', () {
    expect(
      IosCalendarRepositoryImpl.safeDocumentId('a/b'),
      isNot(IosCalendarRepositoryImpl.safeDocumentId('a%2Fb')),
    );
  });
}
