import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:comiverse_mobile/src/widgets/comiverse_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('React wordmark stays sharp and accessible in both themes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    Future<void> pumpLogo(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: Center(child: ComiVerseLogo(height: 30))),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpLogo(AppTheme.light());
    expect(find.bySemanticsLabel('ComiVerse'), findsOneWidget);
    expect(tester.getSize(find.byType(ComiVerseLogo)), const Size(180, 30));
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        'assets/branding/comiverse_logo_light.png',
      ),
    );
    expect(tester.takeException(), isNull);

    await pumpLogo(AppTheme.dark());
    expect(find.bySemanticsLabel('ComiVerse'), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        'assets/branding/comiverse_logo_dark.png',
      ),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
