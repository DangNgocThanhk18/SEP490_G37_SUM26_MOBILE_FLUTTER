import 'dart:convert';

import 'package:comiverse_mobile/src/models/chapter.dart';
import 'package:comiverse_mobile/src/models/comic.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/screens/comic_detail_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/session_storage.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('comic rating endpoints use the authenticated API contract', () async {
    final storage = _MemorySessionStorage({
      'comiverse_access_token': 'reader-access-token',
      'comiverse_user_profile': jsonEncode({
        'userId': 'reader-1',
        'username': 'reader',
        'email': 'reader@comiverse.test',
      }),
    });
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'http://localhost:8081/api',
      sessionStorage: storage,
      httpClient: MockClient((request) async {
        requests.add(request);
        final responseData = switch (request.method) {
          'GET' => {
            'comicId': 'comic-1',
            'ratingAverage': 4.2,
            'ratingCount': 7,
            'userScore': null,
          },
          'POST' => {
            'comicId': 'comic-1',
            'ratingAverage': 4.1,
            'ratingCount': 8,
            'userScore': 4,
          },
          _ => {
            'comicId': 'comic-1',
            'ratingAverage': 4.0,
            'ratingCount': 7,
            'userScore': null,
          },
        };
        return http.Response(
          jsonEncode({'success': true, 'data': responseData}),
          200,
        );
      }),
    );
    await client.restoreSession();

    final initial = await client.getComicRating('comic-1');
    final updated = await client.rateComic('comic-1', 4);
    final removed = await client.deleteComicRating('comic-1');

    expect(initial.ratingAverage, 4.2);
    expect(initial.ratingCount, 7);
    expect(updated.userScore, 4);
    expect(removed.userScore, isNull);
    expect(requests.map((request) => request.method), [
      'GET',
      'POST',
      'DELETE',
    ]);
    expect(
      requests.map((request) => request.url.path),
      List.filled(3, '/api/ratings/comics/comic-1'),
    );
    expect(
      requests.every(
        (request) =>
            request.headers['authorization'] == 'Bearer reader-access-token',
      ),
      isTrue,
    );
    expect(jsonDecode(requests[1].body), {'score': 4});
  });

  testWidgets('comic detail displays and updates a five-star rating', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final apiClient = _RatingApiClient();

    await tester.pumpWidget(_ratingApp(apiClient));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('comic-rating-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('comic-rating-average')), findsOneWidget);
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('/ 5 (7 ratings)'), findsOneWidget);
    for (var score = 1; score <= 5; score++) {
      expect(find.byKey(ValueKey('comic-rating-star-$score')), findsOneWidget);
    }

    final fourthStar = find.byKey(const ValueKey('comic-rating-star-4'));
    await tester.ensureVisible(fourthStar);
    await tester.tap(fourthStar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(apiClient.lastRatedScore, 4);
    expect(find.text('4.1'), findsOneWidget);
    expect(find.text('/ 5 (8 ratings)'), findsOneWidget);
    expect(find.text('Your rating: 4/5'), findsOneWidget);
    expect(find.byKey(const ValueKey('remove-comic-rating')), findsOneWidget);
  });

  testWidgets('removing a rating requires an explicit confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final apiClient = _RatingApiClient(initialUserScore: 4);

    await tester.pumpWidget(_ratingApp(apiClient));
    await tester.pumpAndSettle();

    final removeButton = find.byKey(const ValueKey('remove-comic-rating'));
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Remove your rating?'), findsOneWidget);

    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    expect(find.text('Remove your rating?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove rating'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(apiClient.ratingDeleted, isTrue);
    expect(find.byKey(const ValueKey('remove-comic-rating')), findsNothing);
  });
}

Widget _ratingApp(ApiClient apiClient) => MaterialApp(
  theme: AppTheme.light(),
  home: ComicDetailScreen(apiClient: apiClient, comic: _RatingApiClient.comic),
);

class _RatingApiClient extends ApiClient {
  _RatingApiClient({int? initialUserScore})
    : _rating = ComicRating(
        comicId: comic.id,
        ratingAverage: 4.2,
        ratingCount: 7,
        userScore: initialUserScore,
      ),
      super(baseUrl: 'http://localhost/api');

  static const comic = Comic(
    id: 'comic-1',
    title: 'Rating Test Comic',
    summary: 'A comic used to verify the mobile rating workflow.',
    authorName: 'ComiVerse Studio',
    status: 'ONGOING',
    ratingAverage: 4.2,
    ratingCount: 7,
  );

  ComicRating _rating;
  int? lastRatedScore;
  bool ratingDeleted = false;

  @override
  bool get hasToken => true;

  @override
  UserProfile get currentUser => const UserProfile(
    userId: 'reader-1',
    username: 'reader',
    email: 'reader@comiverse.test',
  );

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
  Future<List<String>> getComicTranslationLanguages(String comicId) async =>
      const [];

  @override
  Future<ComicRating> getComicRating(String comicId) async => _rating;

  @override
  Future<ComicRating> rateComic(String comicId, int score) async {
    lastRatedScore = score;
    _rating = ComicRating(
      comicId: comicId,
      ratingAverage: 4.1,
      ratingCount: 8,
      userScore: score,
    );
    return _rating;
  }

  @override
  Future<ComicRating> deleteComicRating(String comicId) async {
    ratingDeleted = true;
    _rating = ComicRating(comicId: comicId, ratingAverage: 4.0, ratingCount: 6);
    return _rating;
  }
}

class _MemorySessionStorage implements SessionStorage {
  _MemorySessionStorage([Map<String, String>? initial]) {
    if (initial != null) _values.addAll(initial);
  }

  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
