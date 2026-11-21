import 'package:flutter_test/flutter_test.dart';
import 'package:forgewatch_mobile/main.dart';

void main() {
  testWidgets('login screen renders project branding', (tester) async {
    await tester.pumpWidget(const ForgeWatchApp());
    expect(
        find.text(
            'MACHINE LEARNING-BASED\nFAULT DETECTION AND\nPREDICTION SYSTEM'),
        findsOneWidget);
    expect(find.text('FORGEWATCH  /  INTELLIGENT MACHINE MONITORING'),
        findsOneWidget);
    expect(find.text('New operator? Create an account'), findsOneWidget);
  });
}
