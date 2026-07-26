import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AppPreferences {
  Future<String?> readLanguageCode();

  Future<void> writeLanguageCode(String languageCode);

  Future<String?> readThemeMode();

  Future<void> writeThemeMode(String themeMode);
}

class SecureAppPreferences implements AppPreferences {
  const SecureAppPreferences({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _languageKey = 'comiverse_language';
  static const _themeModeKey = 'comiverse_theme_mode';

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
}
