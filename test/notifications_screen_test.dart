import 'package:comiverse_mobile/src/models/app_notification.dart';
import 'package:comiverse_mobile/src/screens/notifications_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('marks a notification as read before opening its action', (
    tester,
  ) async {
    final apiClient = _NotificationApiClient();
    AppNotification? opened;
    var unreadCount = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: NotificationsScreen(
          apiClient: apiClient,
          isGuest: false,
          onSignIn: () {},
          onUnreadChanged: (value) => unreadCount = value,
          onOpenNotification: (notification) async => opened = notification,
          refreshSignal: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New forum reply'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(unreadCount, 1);

    await tester.tap(find.text('New forum reply'));
    await tester.pumpAndSettle();

    expect(apiClient.markedIds, ['notification-1']);
    expect(opened?.id, 'notification-1');
    expect(opened?.isRead, isTrue);
    expect(unreadCount, 0);
  });

  testWidgets('forum notifications appear in the Interaction filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: NotificationsScreen(
          apiClient: _NotificationApiClient(),
          isGuest: false,
          onSignIn: () {},
          onUnreadChanged: (_) {},
          onOpenNotification: (_) async {},
          refreshSignal: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Interaction'));
    await tester.pump();

    expect(find.text('New forum reply'), findsOneWidget);
  });

  testWidgets('mark all updates the unread count without reloading the list', (
    tester,
  ) async {
    final apiClient = _NotificationApiClient();
    var unreadCount = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: NotificationsScreen(
          apiClient: apiClient,
          isGuest: false,
          onSignIn: () {},
          onUnreadChanged: (value) => unreadCount = value,
          onOpenNotification: (_) async {},
          refreshSignal: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();

    expect(apiClient.markedAll, isTrue);
    expect(apiClient.notificationLoads, 1);
    expect(unreadCount, 0);
  });
}

class _NotificationApiClient extends ApiClient {
  _NotificationApiClient() : super(baseUrl: 'http://localhost/api');

  final List<String> markedIds = [];
  bool markedAll = false;
  int notificationLoads = 0;

  @override
  bool get hasToken => true;

  @override
  Future<List<AppNotification>> getNotifications() async {
    notificationLoads++;
    return [
      AppNotification(
        id: 'notification-1',
        title: 'New forum reply',
        message: 'Another reader replied to your comment.',
        type: 'FORUM',
        isRead: false,
        createdAt: DateTime.now(),
        actionUrl: '/forum/thread/thread-1?comment=comment-1',
      ),
    ];
  }

  @override
  Future<void> markNotificationRead(String id) async {
    markedIds.add(id);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    markedAll = true;
  }
}
