import 'package:comiverse_mobile/src/models/app_notification.dart';
import 'package:comiverse_mobile/src/models/chapter.dart';
import 'package:comiverse_mobile/src/models/comic.dart';
import 'package:comiverse_mobile/src/models/premium_plan.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/screens/comic_detail_screen.dart';
import 'package:comiverse_mobile/src/screens/main_shell.dart';
import 'package:comiverse_mobile/src/screens/premium_screen.dart';
import 'package:comiverse_mobile/src/screens/reader_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reader shell has no overflow at 320dp with text scaling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final apiClient = _FakeApiClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MainShell(
            apiClient: apiClient,
            user: _FakeApiClient.user,
            onSignOut: () {},
            onToggleTheme: () {},
            isDarkMode: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const PageStorageKey('home-scroll')),
      const Offset(0, -1500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const PageStorageKey('library-scroll-0')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const PageStorageKey('profile-scroll')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail, reader and premium have no overflow at 320dp', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final apiClient = _FakeApiClient();

    Widget testApp(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 700),
          textScaler: TextScaler.linear(1.3),
        ),
        child: child,
      ),
    );

    await tester.pumpWidget(
      testApp(
        ComicDetailScreen(
          apiClient: apiClient,
          comic: _FakeApiClient.comics.first,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final chapters = await apiClient.getChapters('comic-1');
    await tester.pumpWidget(
      testApp(
        ReaderScreen(
          apiClient: apiClient,
          chapters: chapters,
          initialIndex: 0,
          comicTitle: 'A Very Long Responsive Comic Reader Title',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      testApp(PremiumScreen(apiClient: apiClient, user: _FakeApiClient.user)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://localhost/api');

  static const user = UserProfile(
    username: 'reader',
    email: 'reader@comiverse.test',
    fullName: 'ComiVerse Reader',
    role: 'READER',
  );

  static final comics = List.generate(
    10,
    (index) => Comic(
      id: 'comic-$index',
      title: 'A Responsive Comic Title Number $index',
      summary: 'A published comic used to validate responsive Flutter layouts.',
      authorName: 'ComiVerse Studio',
      status: index.isEven ? 'ONGOING' : 'COMPLETED',
      latestChapterNumber: '${index + 10}',
      chapterCount: 120,
      viewCount: 1250000,
      ratingAverage: 4.8,
      genres: const ['Action', 'Fantasy'],
    ),
  );

  @override
  bool get hasToken => true;

  @override
  Future<List<Comic>> getComics() async => comics;

  @override
  Future<List<Comic>> getTopViewed({int size = 10}) async =>
      comics.take(size).toList();

  @override
  Future<List<Comic>> getRecentlyUpdated({int size = 10}) async =>
      comics.take(size).toList();

  @override
  Future<List<Comic>> getRecommendations({int size = 10}) async =>
      comics.take(size).toList();

  @override
  Future<List<Comic>> getSavedComics() async => comics;

  @override
  Future<List<Comic>> getLikedComics() async => comics;

  @override
  Future<List<Comic>> getReadingHistory() async => comics;

  @override
  Future<int> getUnreadNotificationCount() async => 1;

  @override
  Future<List<AppNotification>> getNotifications() async => [
    AppNotification(
      id: 'notification-1',
      title: 'A new chapter is now available',
      message: 'Continue reading your favorite ComiVerse story.',
      type: 'NEW_CHAPTER',
      isRead: false,
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<void> markNotificationRead(String id) async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<Comic> getComicDetail(String id) async => comics.first;

  @override
  Future<List<ChapterLite>> getChapters(String comicId) async => const [
    ChapterLite(
      id: 'chapter-1',
      comicId: 'comic-1',
      chapterNumber: '1',
      title: 'Chapter 1: A Responsive Beginning',
    ),
  ];

  @override
  Future<ChapterDetail> getChapterDetail(String chapterId) async =>
      const ChapterDetail(
        id: 'chapter-1',
        title: 'Chapter 1: A Responsive Beginning',
        chapterNumber: '1',
        images: [],
      );

  @override
  Future<Set<String>> getReadChapterIds(String comicId) async => const {};

  @override
  Future<bool> checkSaved(String comicId) async => false;

  @override
  Future<bool> checkLiked(String comicId) async => false;

  @override
  Future<PremiumPlanSettings> getPremiumPlans() async =>
      const PremiumPlanSettings(
        monthlyPrice: 49000,
        yearlyPrice: 499000,
        benefits: ['Ad-free reading', 'Early chapter access'],
      );
}
