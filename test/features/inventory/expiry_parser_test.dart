import 'package:butlu/features/inventory/models/expiry_parser.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 4);

DateTime? _parse(List<String> lines) => parseExpiryDate(lines, now: _now);

void main() {
  test('German MHD with a two-digit year', () {
    expect(_parse(['MHD 12.11.26']), DateTime(2026, 11, 12));
  });

  test('keyword on the line before the date', () {
    expect(
      _parse(['Mindestens haltbar bis:', '05.01.2027', 'L 2304']),
      DateTime(2027, 1, 5),
    );
  });

  test('expiry beats the packing date on the same pack', () {
    expect(
      _parse(['Verpackt am 01.11.26', 'zu verbrauchen bis 08.11.26']),
      DateTime(2026, 11, 8),
    );
  });

  test('slashes, dashes and ISO dates', () {
    expect(_parse(['BEST BEFORE 12/11/2026']), DateTime(2026, 11, 12));
    expect(_parse(['EXP 2027-03-01']), DateTime(2027, 3, 1));
    expect(_parse(['12-11-26']), DateTime(2026, 11, 12));
  });

  test('month names, English and German', () {
    expect(_parse(['BB 12 NOV 2026']), DateTime(2026, 11, 12));
    expect(_parse(['MHD 3. Dez 26']), DateTime(2026, 12, 3));
  });

  test('month and year only means the end of that month', () {
    expect(_parse(['MHD 11.2027']), DateTime(2027, 11, 30));
    expect(_parse(['Best before end 02/28']), DateTime(2028, 2, 29));
  });

  test('common OCR slips are corrected', () {
    expect(_parse(['MHD 1O.12.26']), DateTime(2026, 12, 10));
    expect(_parse(['MHD 12 . 11 . 26']), DateTime(2026, 11, 12));
  });

  test('impossible or far-off numbers are ignored', () {
    expect(_parse(['Charge 31.13.26']), isNull);
    expect(_parse(['Price 1.99']), isNull);
    expect(_parse(['Nothing here']), isNull);
    expect(_parse(['01.01.1999']), isNull);
  });
}
