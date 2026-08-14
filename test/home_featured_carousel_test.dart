import 'package:comiverse_mobile/src/models/comic.dart';
import 'package:comiverse_mobile/src/screens/home_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('featured comics auto-play, swipe, and respond to indicators', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          apiClient: _CarouselApiClient(),
          onOpenExplore: () {},
          onOpenNotifications: () {},
          unreadCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageViewFinder = find.byKey(
      const ValueKey('home-featured-page-view'),
    );
    expect(pageViewFinder, findsOneWidget);
    expect(_logicalPage(tester, pageViewFinder), 0);
    for (var index = 0; index < 3; index++) {
      expect(
        find.byKey(ValueKey('home-featured-indicator-$index')),
        findsOneWidget,
      );
    }

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_logicalPage(tester, pageViewFinder), 1);

    await tester.drag(pageViewFinder, const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(_logicalPage(tester, pageViewFinder), 0);

    await tester.tap(find.byKey(const ValueKey('home-featured-indicator-2')));
    await tester.pumpAndSettle();
    expect(_logicalPage(tester, pageViewFinder), 2);
    expect(tester.takeException(), isNull);
  });
}

int _logicalPage(WidgetTester tester, Finder pageViewFinder) {
  final pageView = tester.widget<PageView>(pageViewFinder);
  return pageView.controller!.page!.round() % _CarouselApiClient.comics.length;
}

class _CarouselApiClient extends ApiClient {
  _CarouselApiClient() : super(baseUrl: 'http://localhost/api');

  static const comics = [
    Comic(
      id: 'comic-1',
      title: 'Featured One',
      summary: 'First featured comic.',
      authorName: 'ComiVerse Studio',
      status: 'ONGOING',
      latestChapterNumber: '1',
      chapterCount: 1,
      ratingAverage: 4.1,
      genres: ['Action'],
    ),
    Comic(
      id: 'comic-2',
      title: 'Featured Two',
      summary: 'Second featured comic.',
      authorName: 'ComiVerse Studio',
      status: 'ONGOING',
      latestChapterNumber: '2',
      chapterCount: 2,
      ratingAverage: 4.2,
      genres: ['Fantasy'],
    ),
    Comic(
      id: 'comic-3',
      title: 'Featured Three',
      summary: 'Third featured comic.',
      authorName: 'ComiVerse Studio',
      status: 'ONGOING',
      latestChapterNumber: '3',
      chapterCount: 3,
      ratingAverage: 4.3,
      genres: ['Drama'],
    ),
  ];

  @override
  Future<List<Comic>> getLeaderboard({String timeframe = 'all'}) async =>
      comics;

  @override
  Future<List<Comic>> getRecommendations({int size = 10}) async => comics;

  @override
  Future<List<Comic>> getRecentlyUpdated({int size = 10}) async => comics;
}
