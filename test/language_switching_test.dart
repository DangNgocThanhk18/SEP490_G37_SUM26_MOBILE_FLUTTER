import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comiverse_mobile/src/app.dart';
import 'package:comiverse_mobile/src/models/app_notification.dart';
import 'package:comiverse_mobile/src/models/comic.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/app_preferences.dart';
import 'package:comiverse_mobile/src/services/session_storage.dart';

void main() {
  testWidgets('uses English when no language preference is stored', (
    WidgetTester tester,
  ) async {
    final preferences = _MemoryAppPreferences();

    await tester.pumpWidget(
      ComiVerseApp(apiClient: _TestApiClient(), preferences: preferences),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(preferences.languageCode, isNull);
  });

  testWidgets('switches to Vietnamese immediately and restores it', (
    WidgetTester tester,
  ) async {
    final preferences = _MemoryAppPreferences();

    await tester.pumpWidget(
      ComiVerseApp(
        apiClient: _TestApiClient(restoredUser: _reader),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    final profileList = find.byKey(const PageStorageKey('profile-scroll'));
    expect(profileList, findsOneWidget);
    await tester.drag(profileList, const Offset(0, -500));
    await tester.pumpAndSettle();

    final languageTile = find.text('Language');
    expect(languageTile, findsOneWidget);
    await tester.ensureVisible(languageTile);
    await tester.pumpAndSettle();
    await tester.tap(languageTile);
    await tester.pumpAndSettle();

    expect(find.text('Select language'), findsOneWidget);
    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();

    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Hồ sơ'), findsWidgets);
    expect(preferences.languageCode, 'vi');

    // Let the language-change notification auto-dismiss before recreating the
    // root widget, then dispose MainShell so its polling timer is cancelled.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      ComiVerseApp(
        apiClient: _TestApiClient(restoredUser: _reader),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Khám phá'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

const _reader = UserProfile(
  username: 'reader',
  email: 'reader@comiverse.test',
  fullName: 'ComiVerse Reader',
  role: 'READER',
);

class _MemoryAppPreferences implements AppPreferences {
  String? languageCode;

  @override
  Future<String?> readLanguageCode() async => languageCode;

  @override
  Future<void> writeLanguageCode(String languageCode) async {
    this.languageCode = languageCode;
  }
}

class _TestApiClient extends ApiClient {
  _TestApiClient({this.restoredUser})
    : super(
        baseUrl: 'http://localhost/api',
        sessionStorage: _EmptySessionStorage(),
      );

  final UserProfile? restoredUser;

  @override
  bool get hasToken => restoredUser != null;

  @override
  Future<UserProfile?> restoreSession() async => restoredUser;

  @override
  Future<List<Comic>> getComics() async => const [];

  @override
  Future<List<Comic>> getTopViewed({int size = 10}) async => const [];

  @override
  Future<List<Comic>> getRecommendations({int size = 10}) async => const [];

  @override
  Future<List<Comic>> getRecentlyUpdated({int size = 10}) async => const [];

  @override
  Future<List<Comic>> getReadingHistory() async => const [];

  @override
  Future<List<Comic>> getSavedComics() async => const [];

  @override
  Future<List<AppNotification>> getNotifications() async => const [];

  @override
  Future<int> getUnreadNotificationCount() async => 0;
}

class _EmptySessionStorage implements SessionStorage {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
