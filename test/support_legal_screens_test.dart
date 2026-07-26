import 'package:comiverse_mobile/src/l10n/app_localizations.dart';
import 'package:comiverse_mobile/src/screens/support_legal_screens.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  testWidgets('support and legal screens remain responsive at 320dp', (
    tester,
  ) async {
    for (final screen in const <Widget>[
      HelpCenterScreen(),
      PrivacyPolicyScreen(),
      TermsOfServiceScreen(),
    ]) {
      await tester.pumpWidget(_app(screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Help Center content is localized to Vietnamese', (tester) async {
    await tester.pumpWidget(
      _app(const HelpCenterScreen(), locale: const Locale('vi')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chúng tôi có thể giúp gì cho bạn?'), findsOneWidget);
    expect(find.text('Câu hỏi thường gặp'), findsOneWidget);
  });
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: MediaQuery(
    data: const MediaQueryData(
      size: Size(320, 700),
      textScaler: TextScaler.linear(1.2),
    ),
    child: home,
  ),
);
