import 'dart:async';
import 'dart:convert';

import 'package:comiverse_mobile/src/models/chat_message.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/screens/global_chat_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/global_chat_realtime.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Global Chat API contract', () {
    test('loads paginated GLOBAL messages and maps websocket URL', () async {
      http.Request? captured;
      final client = ApiClient(
        baseUrl: 'https://api.comiverse.test/api',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'metadata': {'page': 1, 'limit': 30, 'totalPages': 2},
              'data': [
                {
                  'id': 'message-1',
                  'senderId': 'user-2',
                  'senderName': 'Linh',
                  'senderAvatar': '/uploads/linh.jpg',
                  'content': 'Hello ComiVerse',
                  'createdAt': '2026-08-12T10:00:00Z',
                },
              ],
            }),
            200,
          );
        }),
      );

      final page = await client.getGlobalChatMessages(page: 1, limit: 30);

      expect(captured?.url.path, '/api/chat/messages');
      expect(captured?.url.queryParameters['chat_type'], 'GLOBAL');
      expect(captured?.url.queryParameters['page'], '1');
      expect(captured?.url.queryParameters['limit'], '30');
      expect(page.messages.single.senderName, 'Linh');
      expect(page.hasMore, isTrue);
      expect(client.webSocketUrl, 'wss://api.comiverse.test/api/ws');
    });

    test('sends the backend GLOBAL payload and maps its response', () async {
      http.Request? captured;
      final client = ApiClient(
        baseUrl: 'http://localhost:8081/api',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'message-2',
                'senderId': 'user-1',
                'senderName': 'Reader',
                'content': 'A new message',
                'createdAt': '2026-08-12T10:05:00Z',
              },
            }),
            200,
          );
        }),
      );

      final message = await client.sendGlobalChatMessage('  A new message  ');

      expect(captured?.method, 'POST');
      expect(jsonDecode(captured!.body), {
        'chatType': 'GLOBAL',
        'content': 'A new message',
      });
      expect(message.id, 'message-2');
    });
  });

  testWidgets('guest must sign in before using Global Chat', (tester) async {
    var requestedSignIn = false;
    await tester.pumpWidget(
      _testApp(
        GlobalChatScreen(
          apiClient: _ChatApiClient(authenticated: false),
          user: null,
          onSignIn: () => requestedSignIn = true,
        ),
      ),
    );

    expect(find.text('Join the ComiVerse conversation'), findsOneWidget);
    expect(find.byKey(const Key('global-chat-composer')), findsNothing);
    await tester.tap(find.text('Sign In'));
    expect(requestedSignIn, isTrue);
  });

  testWidgets('shows realtime messages once and sends through REST', (
    tester,
  ) async {
    final apiClient = _ChatApiClient(authenticated: true);
    final realtime = _FakeRealtime();
    await tester.pumpWidget(
      _testApp(
        GlobalChatScreen(
          apiClient: apiClient,
          user: _ChatApiClient.reader,
          onSignIn: () {},
          realtime: realtime,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(realtime.didConnect, isTrue);
    expect(find.text('Welcome to Global Chat'), findsOneWidget);
    realtime.emit(
      _message(
        id: 'live-1',
        senderId: 'user-2',
        senderName: 'Linh',
        content: 'Realtime hello',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Realtime hello'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('global-chat-composer')),
      'Mobile says hi',
    );
    await tester.tap(find.byKey(const Key('global-chat-send')));
    await tester.pumpAndSettle();
    expect(apiClient.sentContents, ['Mobile says hi']);
    expect(find.text('Mobile says hi'), findsOneWidget);

    realtime.emit(apiClient.sentMessage!);
    await tester.pumpAndSettle();
    expect(find.text('Mobile says hi'), findsOneWidget);
  });
}

Widget _testApp(Widget home) =>
    MaterialApp(theme: AppTheme.light(), home: home);

ChatMessage _message({
  required String id,
  required String senderId,
  required String senderName,
  required String content,
}) {
  return ChatMessage(
    id: id,
    senderId: senderId,
    senderName: senderName,
    content: content,
    createdAt: DateTime.utc(2026, 8, 12, 10),
  );
}

class _ChatApiClient extends ApiClient {
  _ChatApiClient({required this.authenticated})
    : super(baseUrl: 'http://localhost:8081/api');

  static const reader = UserProfile(
    userId: 'user-1',
    username: 'reader',
    email: 'reader@comiverse.test',
    fullName: 'Reader One',
  );

  final bool authenticated;
  final List<String> sentContents = [];
  ChatMessage? sentMessage;

  @override
  bool get hasToken => authenticated;

  @override
  String? get accessToken => authenticated ? 'test-token' : null;

  @override
  UserProfile? get currentUser => authenticated ? reader : null;

  @override
  Future<ChatMessagePage> getGlobalChatMessages({
    int page = 1,
    int limit = 30,
  }) async {
    return ChatMessagePage(
      messages: page == 1
          ? [
              _message(
                id: 'history-1',
                senderId: 'user-2',
                senderName: 'Linh',
                content: 'Welcome to Global Chat',
              ),
            ]
          : const [],
      hasMore: false,
    );
  }

  @override
  Future<ChatMessage> sendGlobalChatMessage(String content) async {
    sentContents.add(content);
    sentMessage = _message(
      id: 'sent-1',
      senderId: 'user-1',
      senderName: 'Reader One',
      content: content,
    );
    return sentMessage!;
  }
}

class _FakeRealtime implements GlobalChatRealtime {
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _statusController = StreamController<ChatConnectionStatus>.broadcast();
  bool didConnect = false;

  @override
  Stream<ChatMessage> get messages => _messageController.stream;

  @override
  Stream<ChatConnectionStatus> get statuses => _statusController.stream;

  @override
  void connect() {
    didConnect = true;
    _statusController.add(ChatConnectionStatus.connected);
  }

  void emit(ChatMessage message) => _messageController.add(message);

  @override
  void dispose() {
    unawaited(_messageController.close());
    unawaited(_statusController.close());
  }
}
