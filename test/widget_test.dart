import 'package:flutter_test/flutter_test.dart';

import 'package:comiverse_mobile/src/app.dart';

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ComiVerseApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
