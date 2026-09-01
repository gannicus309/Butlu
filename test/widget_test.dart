import 'package:butlu/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Calendar tab with all five nav destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ButluApp()));
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Grocery'), findsOneWidget);
    expect(find.text('Chores'), findsOneWidget);
    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('tapping a day with events opens its day-detail list',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ButluApp()));
    await tester.pumpAndSettle();

    // The mock data seeds a "Date night" event tomorrow; today (day 0) always
    // has at least the mock pediatrician event, so tap today's cell.
    final today = DateTime.now().day.toString();
    await tester.tap(find.text(today).first);
    await tester.pumpAndSettle();

    expect(find.text('Pediatrician checkup'), findsOneWidget);
  });
}
