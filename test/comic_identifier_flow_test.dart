import 'package:comiverse_mobile/src/models/chapter.dart';
import 'package:comiverse_mobile/src/models/comic.dart';
import 'package:comiverse_mobile/src/models/content_comment.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/screens/comic_detail_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'SEO comic input is resolved before chapter and reader interactions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final apiClient = _IdentifierApiClient();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ComicDetailScreen(
            apiClient: apiClient,
            comic: const Comic(
              id: 'solo-leveling',
              slug: 'solo-leveling',
              title: 'Solo Leveling',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(apiClient.detailIdentifiers, ['solo-leveling']);
      expect(apiClient.dependentComicIds, isNotEmpty);
      expect(
        apiClient.dependentComicIds,
        everyElement(_IdentifierApiClient.comicId),
      );

      final saveButton = find.widgetWithText(OutlinedButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 300));

      final likeButton = find.text('Like');
      await tester.ensureVisible(likeButton);
      await tester.tap(likeButton);
      await tester.pump(const Duration(milliseconds: 300));

      final ratingButton = find.byKey(const ValueKey('comic-rating-star-4'));
      await tester.ensureVisible(ratingButton);
      await tester.tap(ratingButton);
      await tester.pump(const Duration(milliseconds: 300));

      final commentsTab = find.text('Comments');
      await tester.ensureVisible(commentsTab);
      await tester.tap(commentsTab);
      await tester.pumpAndSettle();

      expect(apiClient.savedComicId, _IdentifierApiClient.comicId);
      expect(apiClient.likedComicId, _IdentifierApiClient.comicId);
      expect(apiClient.ratedComicId, _IdentifierApiClient.comicId);
      expect(apiClient.commentComicId, _IdentifierApiClient.comicId);
    },
  );
}

class _IdentifierApiClient extends ApiClient {
  _IdentifierApiClient() : super(baseUrl: 'http://localhost/api');

  static const comicId = '019f804b-18fb-7d98-8fe1-94c6c72a064a';
  static const chapterId = '019f804b-18fb-7d98-8fe1-94c6c72a064b';

  final List<String> detailIdentifiers = [];
  final List<String> dependentComicIds = [];
  String? savedComicId;
  String? likedComicId;
  String? ratedComicId;
  String? commentComicId;

  @override
  bool get hasToken => true;

  @override
  UserProfile get currentUser => const UserProfile(
    userId: 'reader-1',
    username: 'reader',
    email: 'reader@comiverse.test',
  );

  @override
  Future<Comic> getComicDetail(String idOrSlug) async {
    detailIdentifiers.add(idOrSlug);
    return const Comic(
      id: comicId,
      slug: 'solo-leveling',
      title: 'Solo Leveling',
      status: 'ONGOING',
      ratingAverage: 4.5,
      ratingCount: 2,
    );
  }

  @override
  Future<List<ChapterLite>> getChapters(String comicId) async {
    dependentComicIds.add(comicId);
    return const [
      ChapterLite(
        id: chapterId,
        comicId: _IdentifierApiClient.comicId,
        chapterNumber: '9',
        title: 'Chapter 9',
      ),
    ];
  }

  @override
  Future<Set<String>> getReadChapterIds(String comicId) async {
    dependentComicIds.add(comicId);
    return const {};
  }

  @override
  Future<bool> checkSaved(String comicId) async {
    dependentComicIds.add(comicId);
    return false;
  }

  @override
  Future<bool> checkLiked(String comicId) async {
    dependentComicIds.add(comicId);
    return false;
  }

  @override
  Future<ComicRating> getComicRating(String comicId) async {
    dependentComicIds.add(comicId);
    return const ComicRating(
      comicId: _IdentifierApiClient.comicId,
      ratingAverage: 4.5,
      ratingCount: 2,
    );
  }

  @override
  Future<List<String>> getComicTranslationLanguages(String comicId) async {
    dependentComicIds.add(comicId);
    return const [];
  }

  @override
  Future<bool> toggleSaved(String comicId) async {
    savedComicId = comicId;
    return true;
  }

  @override
  Future<bool> toggleLiked(String comicId) async {
    likedComicId = comicId;
    return true;
  }

  @override
  Future<ComicRating> rateComic(String comicId, int score) async {
    ratedComicId = comicId;
    return ComicRating(
      comicId: comicId,
      ratingAverage: 4.6,
      ratingCount: 3,
      userScore: score,
    );
  }

  @override
  Future<ContentCommentPage> getContentComments({
    required ContentCommentTarget target,
    required String targetId,
    String? parentId,
    int page = 1,
    int size = 10,
  }) async {
    commentComicId = targetId;
    return ContentCommentPage(
      items: const [],
      page: page,
      pageSize: size,
      totalElements: 0,
      totalPages: 0,
    );
  }
}
