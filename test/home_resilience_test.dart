import 'package:comiverse_mobile/src/models/comic.dart';
import 'package:comiverse_mobile/src/screens/home_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps Home usable when one content API fails', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          apiClient: _PartiallyFailingApiClient(),
          onOpenExplore: () {},
          onOpenNotifications: () {},
          unreadCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Some sections could not be loaded.'), findsOneWidget);
    expect(find.text('Recommended for You'), findsOneWidget);
    expect(find.text('Fallback recommendation'), findsWidgets);
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
    expect(find.byIcon(Icons.light_mode_outlined), findsNothing);

    await tester.drag(
      find.byKey(const PageStorageKey('home-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Updates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PartiallyFailingApiClient extends ApiClient {
  _PartiallyFailingApiClient() : super(baseUrl: 'http://localhost/api');

  static const comic = Comic(
    id: 'comic-1',
    title: 'Fallback recommendation',
    latestChapterNumber: '12',
    genres: ['Action'],
  );

  @override
  Future<List<Comic>> getTopViewed({int size = 10}) async {
    throw const ApiException('Trending is temporarily unavailable.');
  }

  @override
  Future<List<Comic>> getRecommendations({int size = 10}) async => const [
    comic,
  ];

  @override
  Future<List<Comic>> getRecentlyUpdated({int size = 10}) async => const [
    comic,
  ];
}
