import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:comiverse_mobile/src/widgets/in_app_notification.dart';

void main() {
  testWidgets('all notice variants are responsive and use semantic icons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _TestApp(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              InAppNotifications.success(
                context,
                title: 'Success',
                message: 'Saved.',
                duration: null,
              );
              InAppNotifications.error(
                context,
                title: 'Error',
                message: 'Failed.',
                duration: null,
              );
              InAppNotifications.warning(
                context,
                title: 'Warning',
                message: 'Check this.',
                duration: null,
              );
              InAppNotifications.information(
                context,
                title: 'Information',
                message: 'For your reference.',
                duration: null,
              );
            },
            child: const Text('Show all'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notice renders its action and can be dismissed', (tester) async {
    var actionCalls = 0;

    await tester.pumpWidget(
      _TestApp(
        child: Builder(
          builder: (context) {
            return FilledButton(
              onPressed: () {
                InAppNotifications.success(
                  context,
                  title: 'Saved',
                  message: 'Your changes are ready.',
                  duration: null,
                  action: InAppNotificationAction(
                    label: 'View',
                    onPressed: () => actionCalls++,
                  ),
                );
              },
              child: const Text('Show notice'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show notice'));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Your changes are ready.'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(actionCalls, 1);
    expect(find.text('Your changes are ready.'), findsNothing);
  });

  testWidgets('confirmation uses the custom modal and returns its choice', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      _TestApp(
        child: Builder(
          builder: (context) {
            return FilledButton(
              onPressed: () async {
                result = await InAppModal.confirm(
                  context,
                  title: 'Remove comic?',
                  message: 'This item will leave your library.',
                  confirmLabel: 'Remove',
                  destructive: true,
                );
              },
              child: const Text('Open confirmation'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Remove comic?'), findsOneWidget);
    expect(find.text('This item will leave your library.'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('Remove comic?'), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );
  }
}
