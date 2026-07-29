import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comiverse_mobile/src/app.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/app_preferences.dart';
import 'package:comiverse_mobile/src/services/session_storage.dart';

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ComiVerseApp(
        apiClient: _testApiClient(),
        preferences: const _EmptyAppPreferences(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('switches between dark and light themes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ComiVerseApp(
        apiClient: _testApiClient(),
        preferences: const _EmptyAppPreferences(),
      ),
    );
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

  testWidgets('restores and persists the selected theme', (
    WidgetTester tester,
  ) async {
    final preferences = _MemoryAppPreferences(themeMode: 'dark');
    await tester.pumpWidget(
      ComiVerseApp(apiClient: _testApiClient(), preferences: preferences),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Use light mode'), findsOneWidget);
    await tester.tap(find.byTooltip('Use light mode'));
    await tester.pumpAndSettle();
    expect(preferences.themeMode, 'light');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ComiVerseApp(apiClient: _testApiClient(), preferences: preferences),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Use dark mode'), findsOneWidget);
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

class _EmptyAppPreferences implements AppPreferences {
  const _EmptyAppPreferences();

  @override
  Future<String?> readLanguageCode() async => null;

  @override
  Future<void> writeLanguageCode(String languageCode) async {}

  @override
  Future<String?> readThemeMode() async => null;

  @override
  Future<void> writeThemeMode(String themeMode) async {}

  @override
  Future<String?> readPreferredReadingLanguage() async => null;

  @override
  Future<void> writePreferredReadingLanguage(String? languageCode) async {}
}

class _MemoryAppPreferences implements AppPreferences {
  _MemoryAppPreferences({this.themeMode});

  String? languageCode;
  String? themeMode;
  String? preferredReadingLanguage;

  @override
  Future<String?> readLanguageCode() async => languageCode;

  @override
  Future<String?> readThemeMode() async => themeMode;

  @override
  Future<void> writeLanguageCode(String languageCode) async {
    this.languageCode = languageCode;
  }

  @override
  Future<void> writeThemeMode(String themeMode) async {
    this.themeMode = themeMode;
  }

  @override
  Future<String?> readPreferredReadingLanguage() async =>
      preferredReadingLanguage;

  @override
  Future<void> writePreferredReadingLanguage(String? languageCode) async {
    preferredReadingLanguage = languageCode;
  }
}
