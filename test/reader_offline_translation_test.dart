import 'package:comiverse_mobile/src/models/chapter.dart';
import 'package:comiverse_mobile/src/screens/reader_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/offline_download_service.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline reader loads translations from the downloaded package', (
    tester,
  ) async {
    final apiClient = ApiClient(baseUrl: 'http://localhost/api');
    final downloads = _TranslatedOfflineDownloads(apiClient);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ReaderScreen(
          apiClient: apiClient,
          offlineDownloads: downloads,
          preferOffline: true,
          initialLanguage: 'vi',
          chapters: const [
            ChapterLite(
              id: 'chapter-1',
              comicId: 'comic-1',
              chapterNumber: '1',
              title: 'Chapter 1',
            ),
          ],
          initialIndex: 0,
          comicTitle: 'Offline Comic',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(downloads.translationRequests, ['chapter-1']);
    expect(find.text('VI'), findsOneWidget);
    expect(find.byIcon(Icons.translate_rounded), findsWidgets);
  });
}

class _TranslatedOfflineDownloads extends OfflineDownloadService {
  _TranslatedOfflineDownloads(ApiClient apiClient)
    : super(apiClient: apiClient);

  final List<String> translationRequests = [];

  @override
  Future<ChapterDetail> openChapter(String chapterId) async =>
      const ChapterDetail(
        id: 'chapter-1',
        title: 'Chapter 1',
        chapterNumber: '1',
        comicId: 'comic-1',
        images: [],
      );

  @override
  Future<List<ChapterTranslation>> openTranslations(String chapterId) async {
    translationRequests.add(chapterId);
    return const [
      ChapterTranslation(
        id: 'translation-1',
        languageCode: 'vi',
        pages: [TranslatedPage(pageNumber: 1, imageUrl: '', bubbles: [])],
      ),
    ];
  }
}
