import 'package:comiverse_mobile/src/models/forum.dart';
import 'package:comiverse_mobile/src/screens/forum_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('forum is responsive, searchable, and creates a real thread', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final apiClient = _ForumApiClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.2),
          ),
          child: ForumScreen(apiClient: apiClient),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ComiVerse Community'), findsOneWidget);
    expect(find.text('A friendly welcome thread'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).first, 'release notes');
    await tester.pump();
    expect(find.text('A friendly welcome thread'), findsNothing);
    expect(find.text('July release notes'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    await tester.tap(find.text('New post'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'What should I read next?');
    await tester.enterText(fields.at(1), 'Please share your recommendations.');
    await tester.tap(find.text('Publish discussion'));
    await tester.pumpAndSettle();

    expect(apiClient.createdTitles, ['What should I read next?']);
    expect(find.text('Discussion published.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ForumApiClient extends ApiClient {
  _ForumApiClient() : super(baseUrl: 'http://localhost/api');

  final List<String> createdTitles = [];

  @override
  bool get hasToken => true;

  @override
  Future<List<ForumThread>> getForumThreads() async => [
    ForumThread(
      id: 'thread-1',
      title: 'A friendly welcome thread',
      author: 'ComiVerse Team',
      content: 'Introduce yourself to the community.',
      category: 'General',
      createdAt: DateTime.now(),
      isLocked: false,
      isPinned: true,
      views: 120,
      replies: 8,
    ),
    ForumThread(
      id: 'thread-2',
      title: 'July release notes',
      author: 'Release Bot',
      content: 'Everything added to ComiVerse this month.',
      category: 'News',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isLocked: false,
      views: 42,
      replies: 3,
    ),
  ];

  @override
  Future<ForumThread> createForumThread({
    required String title,
    required String category,
    required String content,
  }) async {
    createdTitles.add(title);
    return ForumThread(
      id: 'created-thread',
      title: title,
      author: 'Reader',
      content: content,
      category: category,
      createdAt: DateTime.now(),
      isLocked: false,
      views: 0,
      replies: 0,
    );
  }
}
