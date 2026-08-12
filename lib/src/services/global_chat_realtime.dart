import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../models/chat_message.dart';
import 'api_client.dart';

enum ChatConnectionStatus { connecting, connected, disconnected }

abstract interface class GlobalChatRealtime {
  Stream<ChatMessage> get messages;
  Stream<ChatConnectionStatus> get statuses;

  void connect();
  void dispose();
}

class StompGlobalChatRealtime implements GlobalChatRealtime {
  StompGlobalChatRealtime({required this.apiClient});

  final ApiClient apiClient;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _statuses = StreamController<ChatConnectionStatus>.broadcast();
  StompClient? _client;
  StompUnsubscribe? _unsubscribe;
  bool _disposed = false;

  @override
  Stream<ChatMessage> get messages => _messages.stream;

  @override
  Stream<ChatConnectionStatus> get statuses => _statuses.stream;

  @override
  void connect() {
    if (_disposed || _client?.isActive == true) return;
    final token = apiClient.accessToken;
    if (token == null || token.isEmpty) {
      _emitStatus(ChatConnectionStatus.disconnected);
      return;
    }

    _emitStatus(ChatConnectionStatus.connecting);
    final authorization = 'Bearer $token';
    late final StompClient client;
    client = StompClient(
      config: StompConfig(
        url: apiClient.webSocketUrl,
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        connectionTimeout: const Duration(seconds: 15),
        stompConnectHeaders: {'Authorization': authorization, 'token': token},
        onConnect: (_) {
          if (_disposed) return;
          _emitStatus(ChatConnectionStatus.connected);
          _unsubscribe = client.subscribe(
            destination: '/topic/chat/global',
            callback: _handleFrame,
          );
        },
        onDisconnect: (_) => _emitStatus(ChatConnectionStatus.disconnected),
        onStompError: (_) => _emitStatus(ChatConnectionStatus.disconnected),
        onWebSocketDone: () {
          _unsubscribe = null;
          _emitStatus(ChatConnectionStatus.disconnected);
        },
        onWebSocketError: (_) => _emitStatus(ChatConnectionStatus.disconnected),
      ),
    );
    _client = client;
    client.activate();
  }

  void _handleFrame(StompFrame frame) {
    final body = frame.body;
    if (_disposed || body == null || body.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        _messages.add(ChatMessage.fromJson(decoded));
      }
    } on FormatException {
      // Ignore malformed broker messages and keep the subscription alive.
    }
  }

  void _emitStatus(ChatConnectionStatus status) {
    if (!_disposed) _statuses.add(status);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _unsubscribe?.call();
    } catch (_) {
      // The socket may already be closed while the screen is being disposed.
    }
    _unsubscribe = null;
    _client?.deactivate();
    _client = null;
    unawaited(_messages.close());
    unawaited(_statuses.close());
  }
}
