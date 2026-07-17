import 'package:flutter_test/flutter_test.dart';

import 'package:comiverse_mobile/src/app.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/session_storage.dart';

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(ComiVerseApp(apiClient: _testApiClient()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('switches between dark and light themes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ComiVerseApp(apiClient: _testApiClient()));
    await tester.pumpAndSettle();

    final startsInDarkMode = find
        .byTooltip('Use light mode')
        .evaluate()
        .isNotEmpty;
    final initialToggle = find.byTooltip(
      startsInDarkMode ? 'Use light mode' : 'Use dark mode',
    );
    expect(initialToggle, findsOneWidget);
    await tester.tap(initialToggle);
    await tester.pump();

    expect(
      find.byTooltip(startsInDarkMode ? 'Use dark mode' : 'Use light mode'),
      findsOneWidget,
    );
  });
}

ApiClient _testApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost/api',
    sessionStorage: _EmptySessionStorage(),
  );
}

class _EmptySessionStorage implements SessionStorage {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
