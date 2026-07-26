import 'package:comiverse_mobile/src/models/forum.dart';
import 'package:comiverse_mobile/src/screens/forum_thread_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads a forum notification target without mobile overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ForumThreadScreen(
          apiClient: _ForumApiClient(),
          threadId: 'thread-1',
          highlightCommentId: 'comment-2',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A notification discussion'), findsOneWidget);
    expect(
      find.text('This is the reply from the notification.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _ForumApiClient extends ApiClient {
  _ForumApiClient() : super(baseUrl: 'http://localhost/api');

  @override
  Future<ForumThread> getForumThread(String threadId) async {
    return ForumThread(
      id: threadId,
      title: 'A notification discussion',
      author: 'Thread Author',
      content: 'The original forum post.',
      category: 'General',
      createdAt: DateTime.now(),
      isLocked: false,
      views: 12,
      replies: 2,
    );
  }

  @override
  Future<List<ForumComment>> getForumComments(String threadId) async {
    return [
      ForumComment(
        id: 'comment-1',
        userId: 'user-1',
        author: 'First Reader',
        content: 'The parent comment.',
        parentId: null,
        avatarUrl: null,
        createdAt: DateTime.now(),
      ),
      ForumComment(
        id: 'comment-2',
        userId: 'user-2',
        author: 'Second Reader',
        content: 'This is the reply from the notification.',
        parentId: 'comment-1',
        avatarUrl: null,
        createdAt: DateTime.now(),
      ),
    ];
  }
}
