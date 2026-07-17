import 'package:flutter_test/flutter_test.dart';

import 'package:comiverse_mobile/src/app.dart';

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ComiVerseApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('switches between dark and light themes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ComiVerseApp());

    expect(find.byTooltip('Use light mode'), findsOneWidget);
    await tester.tap(find.byTooltip('Use light mode'));
    await tester.pump();

    expect(find.byTooltip('Use dark mode'), findsOneWidget);
  });
}
