import 'package:daily_asking/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows privacy onboarding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DailyAskingApp()));
    await tester.pumpAndSettle();

    expect(find.text('先说清楚隐私边界'), findsOneWidget);
    expect(find.text('我理解，开始记录'), findsOneWidget);
  });
}
