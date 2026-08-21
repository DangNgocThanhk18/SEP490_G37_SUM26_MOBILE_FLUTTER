import 'package:comiverse_mobile/src/models/notification_destination.dart';
import 'package:comiverse_mobile/src/models/chapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationDestination', () {
    test('parses forum comment deep links', () {
      final destination = NotificationDestination.parse(
        '/forum/thread/thread-123?comment=comment-456',
      );

      expect(destination.type, NotificationDestinationType.forumThread);
      expect(destination.threadId, 'thread-123');
      expect(destination.commentId, 'comment-456');
    });

    test('parses SEO comic and chapter deep links', () {
      final comic = NotificationDestination.parse(
        '/comic/solo-leveling?comment=comment-1',
      );
      final chapter = NotificationDestination.parse(
        '/comic/solo-leveling/chapter/chapter-9?comment=comment-9',
      );

      expect(comic.type, NotificationDestinationType.comic);
      expect(comic.comicId, 'solo-leveling');
      expect(comic.commentId, 'comment-1');
      expect(chapter.type, NotificationDestinationType.chapter);
      expect(chapter.comicId, 'solo-leveling');
      expect(chapter.chapterId, 'chapter-9');
      expect(chapter.commentId, 'comment-9');
    });

    test('matches SEO chapter numbers and backend chapter IDs', () {
      const chapter = ChapterLite(
        id: '019f804b-18fb-7d98-8fe1-94c6c72a064a',
        comicId: '019f804b-18fb-7d98-8fe1-94c6c72a064b',
        chapterNumber: '9.0',
        title: 'Chapter 9',
      );

      expect(chapter.matchesRouteIdentifier(chapter.id), isTrue);
      expect(chapter.matchesRouteIdentifier('chapter-9'), isTrue);
      expect(chapter.matchesRouteIdentifier('chapter-10'), isFalse);
    });

    test('supports stored legacy comment notification links', () {
      final comic = NotificationDestination.parse(
        '/comics/comic-1?comment=comment-1',
      );
      final chapter = NotificationDestination.parse(
        '/chapters/chapter-9?comment=comment-9',
      );

      expect(comic.type, NotificationDestinationType.comic);
      expect(comic.comicId, 'comic-1');
      expect(comic.commentId, 'comment-1');
      expect(chapter.type, NotificationDestinationType.legacyChapter);
      expect(chapter.chapterId, 'chapter-9');
      expect(chapter.commentId, 'comment-9');
    });

    test('rejects external and protocol-relative URLs', () {
      expect(
        NotificationDestination.parse('https://example.com').type,
        NotificationDestinationType.unsupported,
      );
      expect(
        NotificationDestination.parse('//example.com/profile').type,
        NotificationDestinationType.unsupported,
      );
    });

    test('returns none when an action is not provided', () {
      expect(
        NotificationDestination.parse(null).type,
        NotificationDestinationType.none,
      );
      expect(
        NotificationDestination.parse('  ').type,
        NotificationDestinationType.none,
      );
    });
  });
}
