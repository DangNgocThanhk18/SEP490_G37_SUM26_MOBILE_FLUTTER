import 'package:comiverse_mobile/src/models/notification_preferences.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/screens/profile_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('updates profile through the Spring profile API contract', (
    tester,
  ) async {
    final apiClient = _ProfileApiClient();
    UserProfile? changedUser;
    await tester.pumpWidget(
      _testApp(
        ProfileScreen(
          apiClient: apiClient,
          user: _ProfileApiClient.user,
          isDarkMode: false,
          onToggleTheme: () {},
          onOpenHistory: () {},
          onSignOut: () {},
          onUserChanged: (user) => changedUser = user,
        ),
      ),
    );

    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Updated Reader');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(apiClient.updatedFullName, 'Updated Reader');
    expect(changedUser?.displayName, 'Updated Reader');
    expect(find.text('Profile updated.'), findsOneWidget);
  });

  testWidgets('loads and saves notification preferences from the backend', (
    tester,
  ) async {
    final apiClient = _ProfileApiClient();
    await tester.pumpWidget(
      _testApp(
        ProfileScreen(
          apiClient: apiClient,
          user: _ProfileApiClient.user,
          isDarkMode: false,
          onToggleTheme: () {},
          onOpenHistory: () {},
          onSignOut: () {},
        ),
      ),
    );

    final list = find.byKey(const PageStorageKey('profile-scroll'));
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Notification Preferences'));
    await tester.tap(find.text('Notification Preferences'));
    await tester.pumpAndSettle();

    expect(find.text('System announcements'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();

    expect(apiClient.savedPreferences?['SYSTEM_BROADCASTS'], isFalse);
    expect(find.text('Notification preferences saved.'), findsOneWidget);
  });

  testWidgets('opens Help, Privacy, and Terms from Profile', (tester) async {
    await tester.pumpWidget(
      _testApp(
        ProfileScreen(
          apiClient: _ProfileApiClient(),
          user: _ProfileApiClient.user,
          isDarkMode: false,
          onToggleTheme: () {},
          onOpenHistory: () {},
          onSignOut: () {},
        ),
      ),
    );

    final profileList = find.byKey(const PageStorageKey('profile-scroll'));
    await tester.drag(profileList, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Help Center'));
    await tester.tap(find.text('Help Center'));
    await tester.pumpAndSettle();
    expect(find.text('Frequently Asked Questions'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('1. Information We Collect'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();
    expect(find.text('1. Acceptance of Terms'), findsOneWidget);
  });
}

Widget _testApp(Widget home) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: const MediaQueryData(size: Size(390, 800)),
    child: home,
  ),
);

class _ProfileApiClient extends ApiClient {
  _ProfileApiClient() : super(baseUrl: 'http://localhost/api');

  static const user = UserProfile(
    userId: 'reader-1',
    username: 'reader',
    email: 'reader@comiverse.test',
    fullName: 'ComiVerse Reader',
    role: 'READER',
  );

  String? updatedFullName;
  Map<String, bool>? savedPreferences;

  @override
  Future<UserProfile> updateProfile({
    required String fullName,
    String? avatarUrl,
    String? backgroundImageUrl,
    DateTime? dateOfBirth,
    String? bio,
  }) async {
    updatedFullName = fullName;
    return UserProfile(
      userId: user.userId,
      username: user.username,
      email: user.email,
      fullName: fullName,
      role: user.role,
      avatarUrl: avatarUrl,
      backgroundImageUrl: backgroundImageUrl,
      dateOfBirth: dateOfBirth,
      bio: bio,
    );
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences() async {
    return const NotificationPreferences(
      role: 'READER',
      availableKeys: ['SYSTEM_BROADCASTS', 'FORUM_ACTIVITY'],
      values: {'SYSTEM_BROADCASTS': true, 'FORUM_ACTIVITY': true},
    );
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    Map<String, bool> preferences,
  ) async {
    savedPreferences = Map<String, bool>.from(preferences);
    return NotificationPreferences(
      role: 'READER',
      availableKeys: preferences.keys.toList(),
      values: preferences,
    );
  }
}
