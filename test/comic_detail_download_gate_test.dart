import 'package:comiverse_mobile/src/models/chapter.dart';
import 'package:comiverse_mobile/src/models/comic.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/screens/comic_detail_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('free accounts cannot activate comic downloads', (tester) async {
    await tester.pumpWidget(_app(_DownloadGateApiClient(premiumActive: false)));
    await tester.pumpAndSettle();

    final downloadAction = find.ancestor(
      of: find.byIcon(Icons.lock_outline_rounded),
      matching: find.byType(InkResponse),
    );
    expect(downloadAction, findsOneWidget);
    expect(tester.widget<InkResponse>(downloadAction).onTap, isNull);
  });

  testWidgets('premium accounts can activate comic downloads', (tester) async {
    await tester.pumpWidget(_app(_DownloadGateApiClient(premiumActive: true)));
    await tester.pumpAndSettle();

    final downloadAction = find.ancestor(
      of: find.byIcon(Icons.download_outlined),
      matching: find.byType(InkResponse),
    );
    expect(downloadAction, findsOneWidget);
    expect(tester.widget<InkResponse>(downloadAction).onTap, isNotNull);
  });
}

Widget _app(ApiClient apiClient) => MaterialApp(
  theme: AppTheme.light(),
  home: ComicDetailScreen(
    apiClient: apiClient,
    comic: _DownloadGateApiClient.comic,
  ),
);

class _DownloadGateApiClient extends ApiClient {
  _DownloadGateApiClient({required bool premiumActive})
    : _user = UserProfile(
        userId: 'reader-1',
        username: 'reader',
        email: 'reader@comiverse.test',
        premiumActive: premiumActive,
      ),
      super(baseUrl: 'http://localhost/api');

  static const comic = Comic(
    id: 'comic-1',
    title: 'Download Gate Comic',
    authorName: 'ComiVerse Studio',
    status: 'ONGOING',
  );

  final UserProfile _user;

  @override
  bool get hasToken => true;

  @override
  UserProfile get currentUser => _user;

  @override
  Future<Comic> getComicDetail(String id) async => comic;

  @override
  Future<List<ChapterLite>> getChapters(String comicId) async => const [
    ChapterLite(
      id: 'chapter-1',
      comicId: 'comic-1',
      chapterNumber: '1',
      title: 'Chapter 1',
    ),
  ];

  @override
  Future<Set<String>> getReadChapterIds(String comicId) async => const {};

  @override
  Future<bool> checkSaved(String comicId) async => false;

  @override
  Future<bool> checkLiked(String comicId) async => false;

  @override
  Future<ComicRating> getComicRating(String comicId) async =>
      const ComicRating(comicId: 'comic-1', ratingAverage: 0, ratingCount: 0);

  @override
  Future<List<String>> getComicTranslationLanguages(String comicId) async =>
      const [];
}
