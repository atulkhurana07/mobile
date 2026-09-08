import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chargeease_mobile/main.dart';

void main() {
  testWidgets('ChargeEaseApp renders initial state properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ChargeEaseApp(),
      ),
    );

    // Initial state or Login screen should render
    expect(find.byType(ChargeEaseApp), findsOneWidget);
  });
}
