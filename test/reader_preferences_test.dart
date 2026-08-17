import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comiverse_mobile/src/services/app_preferences.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'secure preferences persist reading mode and chapter position',
    () async {
      const preferences = SecureAppPreferences();

      await preferences.writeComicReadingMode(
        ComicReadingMode.pagedRightToLeft,
      );
      await preferences.writeReaderPosition(
        accountScope: 'user:reader-1',
        chapterId: 'chapter-9',
        position: const SavedReaderPosition(
          pageIndex: 14,
          scrollProgress: 0.42,
        ),
      );

      expect(
        await preferences.readComicReadingMode(),
        ComicReadingMode.pagedRightToLeft,
      );
      final restored = await preferences.readReaderPosition(
        accountScope: 'user:reader-1',
        chapterId: 'chapter-9',
      );
      expect(restored?.pageIndex, 14);
      expect(restored?.scrollProgress, 0.42);
      expect(
        await preferences.readReaderPosition(
          accountScope: 'user:reader-2',
          chapterId: 'chapter-9',
        ),
        isNull,
      );
    },
  );
}
