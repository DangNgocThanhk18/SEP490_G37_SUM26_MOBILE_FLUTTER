import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase client configuration supplied by CI or `flutter run` dart-defines.
///
/// Native `google-services.json` / `GoogleService-Info.plist` configuration is
/// still supported: when these values are absent, Firebase is initialized from
/// the native files instead.
abstract final class FirebaseRuntimeOptions {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.example.comiverseMobile',
  );
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static FirebaseOptions? get currentPlatform {
    final appId = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => _iosAppId,
      _ => _androidAppId,
    };
    if (_apiKey.isEmpty ||
        _projectId.isEmpty ||
        _senderId.isEmpty ||
        appId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: appId,
      messagingSenderId: _senderId,
      projectId: _projectId,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
          ? _iosBundleId
          : null,
    );
  }
}
