import 'package:comiverse_mobile/src/models/app_notification.dart';
import 'package:comiverse_mobile/src/models/chapter.dart';
import 'package:comiverse_mobile/src/models/comic.dart';
import 'package:comiverse_mobile/src/models/premium_plan.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/l10n/app_localizations.dart';
import 'package:comiverse_mobile/src/screens/comic_detail_screen.dart';
import 'package:comiverse_mobile/src/screens/main_shell.dart';
import 'package:comiverse_mobile/src/screens/premium_screen.dart';
import 'package:comiverse_mobile/src/screens/reader_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Vietnamese shell has no overflow at 320dp', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final apiClient = _FakeApiClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            padding: EdgeInsets.only(bottom: 24),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MainShell(
            apiClient: apiClient,
            user: _FakeApiClient.user,
            onSignOut: () {},
            onToggleTheme: () {},
            isDarkMode: false,
            locale: const Locale('vi'),
            onLocaleChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Khám phá'), findsOneWidget);
    final homeAppBar = find.byType(AppBar).first;
    expect(
      find.descendant(of: homeAppBar, matching: find.byType(CircleAvatar)),
      findsNothing,
    );
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.byKey(const Key('main-nav-explore')), findsOneWidget);
    expect(find.byKey(const Key('main-nav-forum')), findsOneWidget);
    expect(find.byKey(const Key('main-nav-home')), findsOneWidget);
    expect(find.byKey(const Key('main-nav-library')), findsOneWidget);
    expect(find.byKey(const Key('main-nav-profile')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomAppBar), findsOneWidget);

    final homeRect = tester.getRect(find.byKey(const Key('main-nav-home')));
    final barRect = tester.getRect(find.byType(BottomAppBar));
    expect(homeRect.height, closeTo(58, 0.1));
    expect(homeRect.top, lessThan(barRect.top));
    expect(barRect.top - homeRect.top, lessThan(30));
    expect(barRect.height, closeTo(92, 0.1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

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

    await tester.tap(find.byKey(const Key('main-nav-home')));
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

  testWidgets('main tabs load lazily and keep their state when revisited', (
    tester,
  ) async {
    final apiClient = _CountingShellApiClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MainShell(
          apiClient: apiClient,
          user: _FakeApiClient.user,
          onSignOut: () {},
          onToggleTheme: () {},
          isDarkMode: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(apiClient.comicsCalls, 0);
    expect(apiClient.savedCalls, 0);

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();
    expect(apiClient.comicsCalls, 1);

    await tester.tap(find.byKey(const Key('main-nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();
    expect(apiClient.comicsCalls, 1);

    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pumpAndSettle();
    expect(apiClient.savedCalls, 1);

    await tester.tap(find.byKey(const Key('main-nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pumpAndSettle();
    expect(apiClient.savedCalls, 1);
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
  Future<List<Comic>> getLeaderboard({String timeframe = 'all'}) async =>
      comics;

  @override
  Future<List<GenreOption>> getGenres() async => const [];

  @override
  Future<ComicCursorPage> exploreComics({
    String? cursor,
    String? referenceId,
    Iterable<String> genreIds = const [],
    String? publicationStatus,
    String sortBy = 'Default',
    int size = 15,
  }) async =>
      ComicCursorPage(comics: comics.take(size).toList(), hasMore: false);

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

class _CountingShellApiClient extends _FakeApiClient {
  int comicsCalls = 0;
  int savedCalls = 0;

  @override
  Future<List<Comic>> getComics() async {
    comicsCalls++;
    return _FakeApiClient.comics;
  }

  @override
  Future<ComicCursorPage> exploreComics({
    String? cursor,
    String? referenceId,
    Iterable<String> genreIds = const [],
    String? publicationStatus,
    String sortBy = 'Default',
    int size = 15,
  }) async {
    comicsCalls++;
    return ComicCursorPage(
      comics: _FakeApiClient.comics.take(size).toList(),
      hasMore: false,
    );
  }

  @override
  Future<List<Comic>> getSavedComics() async {
    savedCalls++;
    return _FakeApiClient.comics;
  }
}
