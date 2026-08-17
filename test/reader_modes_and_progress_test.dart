import 'dart:convert';
import 'dart:typed_data';

import 'package:comiverse_mobile/src/models/chapter.dart';
import 'package:comiverse_mobile/src/screens/reader_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/app_preferences.dart';
import 'package:comiverse_mobile/src/services/offline_download_service.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paged reader restores the saved page', (tester) async {
    final preferences = _MemoryReaderPreferences(
      mode: ComicReadingMode.pagedLeftToRight,
      positions: const {
        'guest|chapter-1': SavedReaderPosition(
          pageIndex: 1,
          scrollProgress: 0.5,
        ),
      },
    );

    await tester.pumpWidget(_readerApp(preferences));
    await _pumpReader(tester);

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.reverse, isFalse);
    expect(pageView.controller!.page, closeTo(1, 0.01));
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap direction and reading progress persist across readers', (
    tester,
  ) async {
    final preferences = _MemoryReaderPreferences(
      mode: ComicReadingMode.pagedLeftToRight,
    );

    await tester.pumpWidget(_readerApp(preferences));
    await _pumpReader(tester);

    var pageRect = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(pageRect.right - 20, pageRect.center.dy));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Page 2 of 3'), findsOneWidget);

    pageRect = tester.getRect(find.byType(PageView));
    await tester.tapAt(pageRect.center);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(find.byTooltip('Reader options'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Paged, next on left'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    var pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.reverse, isTrue);
    pageRect = tester.getRect(find.byType(PageView));
    await tester.tapAt(Offset(pageRect.left + 20, pageRect.center.dy));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Page 3 of 3'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    final saved = preferences.positions['guest|chapter-1'];
    expect(preferences.mode, ComicReadingMode.pagedRightToLeft);
    expect(saved?.pageIndex, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(_readerApp(preferences));
    await _pumpReader(tester);

    pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.reverse, isTrue);
    expect(pageView.controller!.page, closeTo(2, 0.01));
    expect(find.text('Page 3 of 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpReader(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _readerApp(_MemoryReaderPreferences preferences) {
  final apiClient = ApiClient(baseUrl: 'http://localhost/api');
  return MaterialApp(
    theme: AppTheme.light(),
    home: ReaderScreen(
      apiClient: apiClient,
      preferences: preferences,
      offlineDownloads: _ReaderDownloads(apiClient),
      preferOffline: true,
      chapters: const [
        ChapterLite(
          id: 'chapter-1',
          comicId: 'comic-1',
          chapterNumber: '1',
          title: 'Chapter 1',
        ),
      ],
      initialIndex: 0,
      comicTitle: 'Reader Modes',
    ),
  );
}

class _MemoryReaderPreferences implements AppPreferences, ReaderPreferences {
  _MemoryReaderPreferences({
    required this.mode,
    Map<String, SavedReaderPosition> positions = const {},
  }) : positions = Map.of(positions);

  ComicReadingMode mode;
  final Map<String, SavedReaderPosition> positions;
  String? preferredLanguage;

  String _key(String accountScope, String chapterId) =>
      '$accountScope|$chapterId';

  @override
  Future<ComicReadingMode> readComicReadingMode() async => mode;

  @override
  Future<void> writeComicReadingMode(ComicReadingMode mode) async {
    this.mode = mode;
  }

  @override
  Future<SavedReaderPosition?> readReaderPosition({
    required String accountScope,
    required String chapterId,
  }) async => positions[_key(accountScope, chapterId)];

  @override
  Future<void> writeReaderPosition({
    required String accountScope,
    required String chapterId,
    required SavedReaderPosition position,
  }) async {
    positions[_key(accountScope, chapterId)] = position;
  }

  @override
  Future<String?> readLanguageCode() async => null;

  @override
  Future<void> writeLanguageCode(String languageCode) async {}

  @override
  Future<String?> readThemeMode() async => null;

  @override
  Future<void> writeThemeMode(String themeMode) async {}

  @override
  Future<String?> readPreferredReadingLanguage() async => preferredLanguage;

  @override
  Future<void> writePreferredReadingLanguage(String? languageCode) async {
    preferredLanguage = languageCode;
  }
}

class _ReaderDownloads extends OfflineDownloadService {
  _ReaderDownloads(ApiClient apiClient) : super(apiClient: apiClient);

  static final Uint8List _onePixelPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  Future<ChapterDetail> openChapter(String chapterId) async =>
      const ChapterDetail(
        id: 'chapter-1',
        title: 'Chapter 1',
        chapterNumber: '1',
        comicId: 'comic-1',
        images: [
          'comiverse-offline://chapter-1/page/1',
          'comiverse-offline://chapter-1/page/2',
          'comiverse-offline://chapter-1/page/3',
        ],
      );

  @override
  Future<List<ChapterTranslation>> openTranslations(String chapterId) async =>
      const [];

  @override
  Uint8List? getCachedPage(String offlineUri) =>
      Uint8List.fromList(_onePixelPng);

  @override
  Future<Uint8List> readPage(String offlineUri) async =>
      Uint8List.fromList(_onePixelPng);

  @override
  void releasePageBytes(Uint8List bytes) {}
}
