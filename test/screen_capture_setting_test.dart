import 'package:comiverse_mobile/src/services/app_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'screen capture preference is absent until the user changes it',
    () async {
      const preferences = SecureAppPreferences();

      expect(await preferences.readScreenCaptureProtectionEnabled(), isNull);
    },
  );

  test(
    'screen capture preference persists enabled and disabled values',
    () async {
      const preferences = SecureAppPreferences();

      await preferences.writeScreenCaptureProtectionEnabled(false);
      expect(await preferences.readScreenCaptureProtectionEnabled(), isFalse);

      await preferences.writeScreenCaptureProtectionEnabled(true);
      expect(await preferences.readScreenCaptureProtectionEnabled(), isTrue);
    },
  );

  test(
    'invalid stored screen capture preference falls back to unset',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'comiverse_screen_capture_protection': 'invalid',
      });
      const preferences = SecureAppPreferences();

      expect(await preferences.readScreenCaptureProtectionEnabled(), isNull);
    },
  );
}
