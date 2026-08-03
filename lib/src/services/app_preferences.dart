import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AppPreferences {
  Future<String?> readLanguageCode();

  Future<void> writeLanguageCode(String languageCode);

  Future<String?> readThemeMode();

  Future<void> writeThemeMode(String themeMode);

  /// Ngôn ngữ bản dịch manga user muốn đọc (ví dụ: "vi", "en", "jp").
  /// Khác với [readLanguageCode] (ngôn ngữ giao diện app).
  /// Trả về null = đọc bản gốc (không overlay bubble dịch).
  Future<String?> readPreferredReadingLanguage();

  Future<void> writePreferredReadingLanguage(String? languageCode);
}

abstract interface class ScreenCapturePreferences {
  Future<bool?> readScreenCaptureProtectionEnabled();

  Future<void> writeScreenCaptureProtectionEnabled(bool enabled);
}

class SecureAppPreferences implements AppPreferences, ScreenCapturePreferences {
  const SecureAppPreferences({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _languageKey = 'comiverse_language';
  static const _themeModeKey = 'comiverse_theme_mode';
  static const _preferredReadingLangKey = 'comiverse_reading_language';
  static const _screenCaptureProtectionKey =
      'comiverse_screen_capture_protection';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readLanguageCode() => _storage.read(key: _languageKey);

  @override
  Future<void> writeLanguageCode(String languageCode) =>
      _storage.write(key: _languageKey, value: languageCode);

  @override
  Future<String?> readThemeMode() => _storage.read(key: _themeModeKey);

  @override
  Future<void> writeThemeMode(String themeMode) =>
      _storage.write(key: _themeModeKey, value: themeMode);

  @override
  Future<String?> readPreferredReadingLanguage() =>
      _storage.read(key: _preferredReadingLangKey);

  @override
  Future<void> writePreferredReadingLanguage(String? languageCode) async {
    if (languageCode == null) {
      await _storage.delete(key: _preferredReadingLangKey);
    } else {
      await _storage.write(key: _preferredReadingLangKey, value: languageCode);
    }
  }

  @override
  Future<bool?> readScreenCaptureProtectionEnabled() async {
    return switch (await _storage.read(key: _screenCaptureProtectionKey)) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }

  @override
  Future<void> writeScreenCaptureProtectionEnabled(bool enabled) => _storage
      .write(key: _screenCaptureProtectionKey, value: enabled.toString());
}
