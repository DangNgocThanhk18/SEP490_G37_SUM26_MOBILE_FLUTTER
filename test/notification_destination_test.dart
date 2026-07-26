import 'package:comiverse_mobile/src/models/notification_destination.dart';
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

    test('parses comic and chapter deep links', () {
      final comic = NotificationDestination.parse('/comic/comic-1');
      final chapter = NotificationDestination.parse(
        '/comic/comic-1/chapter/chapter-9',
      );

      expect(comic.type, NotificationDestinationType.comic);
      expect(comic.comicId, 'comic-1');
      expect(chapter.type, NotificationDestinationType.chapter);
      expect(chapter.comicId, 'comic-1');
      expect(chapter.chapterId, 'chapter-9');
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
