import 'dart:async';
import 'dart:convert';

import 'package:comiverse_mobile/src/models/notification_preferences.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/screens/profile_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/profile_image_picker.dart';
import 'package:comiverse_mobile/src/services/screen_capture_protection.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('updates profile through the Spring profile API contract', (
    tester,
  ) async {
    final apiClient = _ProfileApiClient();
    final imagePicker = _ProfileImagePicker();
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
          imagePicker: imagePicker,
        ),
      ),
    );

    expect(find.byKey(const Key('profile-background-banner')), findsOneWidget);
    expect(find.byKey(const Key('profile-avatar-image')), findsOneWidget);
    await tester.ensureVisible(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    expect(find.text('Avatar URL'), findsNothing);
    expect(find.text('Background image URL'), findsNothing);

    await tester.tap(find.byKey(const Key('edit-profile-avatar-picker')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('edit-profile-background-picker')),
    );
    await tester.tap(find.byKey(const Key('edit-profile-background-picker')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Updated Reader');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(apiClient.updatedFullName, 'Updated Reader');
    expect(apiClient.uploadedFiles, ['avatar.png', 'background.png']);
    expect(
      apiClient.updatedAvatarUrl,
      'https://res.cloudinary.com/comiverse/avatar.png',
    );
    expect(
      apiClient.updatedBackgroundUrl,
      'https://res.cloudinary.com/comiverse/background.png',
    );
    expect(changedUser?.displayName, 'Updated Reader');
    expect(changedUser?.avatarUrl, apiClient.updatedAvatarUrl);
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
    expect(find.text('Push delivery is ready on 1 device(s).'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();

    expect(apiClient.savedPreferences?['SYSTEM_BROADCASTS'], isFalse);
    expect(find.text('Notification preferences saved.'), findsOneWidget);
  });

  testWidgets('demo profile exposes the screen capture protection switch', (
    tester,
  ) async {
    bool? changedValue;
    await tester.pumpWidget(
      _testApp(
        ProfileScreen(
          apiClient: _ProfileApiClient(),
          user: _ProfileApiClient.user,
          isDarkMode: false,
          onToggleTheme: () {},
          onOpenHistory: () {},
          onSignOut: () {},
          screenCaptureProtectionEnabled: true,
          onScreenCaptureProtectionChanged: (value) => changedValue = value,
        ),
      ),
    );

    expect(ScreenCaptureProtection.canUserConfigure, isTrue);
    final list = find.byKey(const PageStorageKey('profile-scroll'));
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('screen-capture-protection-switch'));
    await tester.ensureVisible(toggle);

    expect(find.text('Screen capture protection'), findsOneWidget);
    expect(tester.widget<Switch>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pump();

    expect(changedValue, isFalse);
  });

  testWidgets('profile hides screen capture control without demo callback', (
    tester,
  ) async {
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

    expect(
      find.byKey(const Key('screen-capture-protection-switch')),
      findsNothing,
    );
  });

  testWidgets('profile image editor has no overflow at 320dp', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.3),
          ),
          child: ProfileScreen(
            apiClient: _ProfileApiClient(),
            user: _ProfileApiClient.user,
            isDarkMode: false,
            onToggleTheme: () {},
            onOpenHistory: () {},
            onSignOut: () {},
            imagePicker: _ProfileImagePicker(),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    expect(find.text('Profile photos'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps editor open and skips profile PUT when upload fails', (
    tester,
  ) async {
    final apiClient = _FailingUploadApiClient();
    await tester.pumpWidget(
      _testApp(
        ProfileScreen(
          apiClient: apiClient,
          user: _ProfileApiClient.user,
          isDarkMode: false,
          onToggleTheme: () {},
          onOpenHistory: () {},
          onSignOut: () {},
          imagePicker: _ProfileImagePicker(),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-profile-avatar-picker')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Upload unavailable.'), findsOneWidget);
    expect(apiClient.updatedFullName, isNull);
  });

  testWidgets('blocks back navigation and form edits while uploading', (
    tester,
  ) async {
    final apiClient = _DelayedUploadApiClient();
    await tester.pumpWidget(
      _testApp(
        ProfileScreen(
          apiClient: apiClient,
          user: _ProfileApiClient.user,
          isDarkMode: false,
          onToggleTheme: () {},
          onOpenHistory: () {},
          onSignOut: () {},
          imagePicker: _ProfileImagePicker(),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-profile-avatar-picker')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    final nameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(nameField.enabled, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Edit profile'), findsOneWidget);

    apiClient.uploadCompleter.complete(
      'https://res.cloudinary.com/comiverse/avatar.png',
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsNothing);
    expect(apiClient.updatedAvatarUrl, contains('avatar.png'));
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
  String? updatedAvatarUrl;
  String? updatedBackgroundUrl;
  final List<String> uploadedFiles = [];
  Map<String, bool>? savedPreferences;

  @override
  Future<String> uploadImage({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    uploadedFiles.add(fileName);
    return 'https://res.cloudinary.com/comiverse/$fileName';
  }

  @override
  Future<UserProfile> updateProfile({
    required String fullName,
    String? avatarUrl,
    String? backgroundImageUrl,
    DateTime? dateOfBirth,
    String? bio,
  }) async {
    updatedFullName = fullName;
    updatedAvatarUrl = avatarUrl;
    updatedBackgroundUrl = backgroundImageUrl;
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
  Future<PushDeviceStatus> getPushDeviceStatus() async =>
      const PushDeviceStatus(serverConfigured: true, registeredDeviceCount: 1);

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

class _ProfileImagePicker implements ProfileImagePicker {
  static final _onePixelPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  Future<ProfileImageSelection?> pick(ProfileImageKind kind) async {
    return ProfileImageSelection(
      bytes: _onePixelPng,
      fileName: kind == ProfileImageKind.avatar
          ? 'avatar.png'
          : 'background.png',
      contentType: 'image/png',
    );
  }
}

class _FailingUploadApiClient extends _ProfileApiClient {
  @override
  Future<String> uploadImage({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) {
    throw const ApiException('Upload unavailable.');
  }
}

class _DelayedUploadApiClient extends _ProfileApiClient {
  final Completer<String> uploadCompleter = Completer<String>();

  @override
  Future<String> uploadImage({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) => uploadCompleter.future;
}
