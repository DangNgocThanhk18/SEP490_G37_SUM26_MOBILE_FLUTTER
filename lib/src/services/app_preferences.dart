import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ComicReadingMode {
  verticalScroll('vertical_scroll'),
  pagedLeftToRight('paged_left_to_right'),
  pagedRightToLeft('paged_right_to_left');

  const ComicReadingMode(this.storageValue);

  final String storageValue;

  bool get isPaged => this != ComicReadingMode.verticalScroll;

  bool get isRightToLeft => this == ComicReadingMode.pagedRightToLeft;

  static ComicReadingMode fromStorage(String? value) {
    for (final mode in values) {
      if (mode.storageValue == value) return mode;
    }
    return ComicReadingMode.verticalScroll;
  }
}

class SavedReaderPosition {
  const SavedReaderPosition({
    required this.pageIndex,
    required this.scrollProgress,
  });

  final int pageIndex;
  final double scrollProgress;

  Map<String, Object> toJson() => {
    'pageIndex': pageIndex,
    'scrollProgress': scrollProgress,
  };

  static SavedReaderPosition? fromJson(Object? source) {
    if (source is! Map<String, dynamic>) return null;
    final rawPageIndex = source['pageIndex'];
    final rawScrollProgress = source['scrollProgress'];
    final pageIndex = rawPageIndex is num
        ? rawPageIndex.toInt()
        : int.tryParse(rawPageIndex?.toString() ?? '');
    final scrollProgress = rawScrollProgress is num
        ? rawScrollProgress.toDouble()
        : double.tryParse(rawScrollProgress?.toString() ?? '');
    if (pageIndex == null || pageIndex < 0 || scrollProgress == null) {
      return null;
    }
    return SavedReaderPosition(
      pageIndex: pageIndex,
      scrollProgress: scrollProgress.clamp(0, 1).toDouble(),
    );
  }
}

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

abstract interface class ReaderPreferences {
  Future<ComicReadingMode> readComicReadingMode();

  Future<void> writeComicReadingMode(ComicReadingMode mode);

  Future<SavedReaderPosition?> readReaderPosition({
    required String accountScope,
    required String chapterId,
  });

  Future<void> writeReaderPosition({
    required String accountScope,
    required String chapterId,
    required SavedReaderPosition position,
  });
}

class SecureAppPreferences
    implements AppPreferences, ScreenCapturePreferences, ReaderPreferences {
  const SecureAppPreferences({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _languageKey = 'comiverse_language';
  static const _themeModeKey = 'comiverse_theme_mode';
  static const _preferredReadingLangKey = 'comiverse_reading_language';
  static const _comicReadingModeKey = 'comiverse_comic_reading_mode';
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
  Future<ComicReadingMode> readComicReadingMode() async =>
      ComicReadingMode.fromStorage(
        await _storage.read(key: _comicReadingModeKey),
      );

  @override
  Future<void> writeComicReadingMode(ComicReadingMode mode) =>
      _storage.write(key: _comicReadingModeKey, value: mode.storageValue);

  @override
  Future<SavedReaderPosition?> readReaderPosition({
    required String accountScope,
    required String chapterId,
  }) async {
    final encoded = await _storage.read(
      key: _readerPositionKey(accountScope, chapterId),
    );
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return SavedReaderPosition.fromJson(jsonDecode(encoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeReaderPosition({
    required String accountScope,
    required String chapterId,
    required SavedReaderPosition position,
  }) => _storage.write(
    key: _readerPositionKey(accountScope, chapterId),
    value: jsonEncode(position.toJson()),
  );

  String _readerPositionKey(String accountScope, String chapterId) {
    final digest = sha256.convert(
      utf8.encode('${accountScope.trim()}|${chapterId.trim()}'),
    );
    return 'comiverse_reader_position_$digest';
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
