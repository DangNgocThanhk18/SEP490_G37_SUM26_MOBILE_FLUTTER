import 'package:comiverse_mobile/src/models/chapter.dart';
import 'package:comiverse_mobile/src/screens/reader_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('premium chapter shows an upgrade gate instead of broken pages', (
    tester,
  ) async {
    const chapter = ChapterLite(
      id: 'premium-chapter',
      comicId: 'comic-1',
      chapterNumber: '12',
      title: 'Premium chapter',
      isPremium: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ReaderScreen(
          apiClient: _PremiumReaderApiClient(),
          chapters: const [chapter],
          initialIndex: 0,
          comicTitle: 'Premium Comic',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium chapter'), findsOneWidget);
    expect(
      find.text(
        'Upgrade your plan to unlock this chapter and continue reading.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Comments'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 12 discussion'), findsOneWidget);
    expect(
      find.text('Sign in to view and join the discussion.'),
      findsOneWidget,
    );
  });
}

class _PremiumReaderApiClient extends ApiClient {
  _PremiumReaderApiClient() : super(baseUrl: 'http://localhost/api');

  @override
  Future<ChapterDetail> getChapterDetail(String chapterId) async {
    return const ChapterDetail(
      id: 'premium-chapter',
      title: 'Premium chapter',
      chapterNumber: '12',
      images: [],
    );
  }

  @override
  Future<List<ChapterTranslation>> getChapterTranslations(
    String chapterId,
  ) async => const [];
}
