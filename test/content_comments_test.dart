import 'dart:convert';

import 'package:comiverse_mobile/src/models/content_comment.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/session_storage.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:comiverse_mobile/src/widgets/content_comment_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'uses the Spring comic comment pagination and mutation contracts',
    () async {
      final requests = <http.Request>[];
      final storage = _CommentSessionStorage({
        'comiverse_access_token': 'token',
        'comiverse_user_profile': jsonEncode({
          'userId': 'user-1',
          'username': 'reader',
          'email': 'reader@comiverse.test',
          'role': 'READER',
        }),
      });
      final client = ApiClient(
        baseUrl: 'http://localhost:8081/api',
        sessionStorage: storage,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'success': true,
                'metadata': {
                  'page': 1,
                  'size': 10,
                  'totalElements': 12,
                  'totalPages': 2,
                },
                'data': [
                  {
                    'id': 'comment-1',
                    'userId': 'user-1',
                    'userName': 'Reader',
                    'content': 'Great chapter',
                    'comicId': 'comic-1',
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'comment-2',
                  'userId': 'user-1',
                  'userName': 'Reader',
                  'content': 'New comment',
                  'comicId': 'comic-1',
                },
              }),
              201,
            );
          }
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );
      await client.restoreSession();

      final page = await client.getContentComments(
        target: ContentCommentTarget.comic,
        targetId: 'comic-1',
      );
      final created = await client.createContentComment(
        target: ContentCommentTarget.comic,
        targetId: 'comic-1',
        content: 'New comment',
      );
      await client.deleteContentComment(
        target: ContentCommentTarget.comic,
        commentId: created.id,
      );

      expect(page.items.single.content, 'Great chapter');
      expect(page.totalElements, 12);
      expect(page.hasMore, isTrue);
      expect(requests[0].url.path, '/api/comments/comics');
      expect(
        requests[0].url.queryParameters,
        containsPair('comicId', 'comic-1'),
      );
      expect(requests[0].url.queryParameters, containsPair('page', '1'));
      final postBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(postBody['comicId'], 'comic-1');
      expect(postBody['content'], 'New comment');
      expect(postBody.containsKey('parentId'), isFalse);
      expect(postBody.containsKey('mentionId'), isFalse);
      expect(requests[2].method, 'DELETE');
      expect(requests[2].url.path, '/api/comments/comics/comment-2');
    },
  );

  testWidgets('guest comment section does not call the protected API', (
    tester,
  ) async {
    var requestCount = 0;
    final client = ApiClient(
      baseUrl: 'http://localhost:8081/api',
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 401);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContentCommentSection(
              apiClient: client,
              target: ContentCommentTarget.chapter,
              targetId: 'chapter-1',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Sign in to view and join the discussion.'),
      findsOneWidget,
    );
    expect(requestCount, 0);
    expect(tester.takeException(), isNull);
  });
}

class _CommentSessionStorage implements SessionStorage {
  _CommentSessionStorage([Map<String, String>? initial]) {
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
