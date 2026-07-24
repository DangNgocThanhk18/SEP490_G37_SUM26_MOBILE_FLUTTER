import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AppPreferences {
  Future<String?> readLanguageCode();

  Future<void> writeLanguageCode(String languageCode);
}

class SecureAppPreferences implements AppPreferences {
  const SecureAppPreferences({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _languageKey = 'comiverse_language';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readLanguageCode() => _storage.read(key: _languageKey);

  @override
  Future<void> writeLanguageCode(String languageCode) =>
      _storage.write(key: _languageKey, value: languageCode);
}
