import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import 'api_client.dart';
import 'firebase_runtime_options.dart';

abstract interface class PushNotificationCoordinator {
  Stream<AppNotification> get foregroundNotifications;
  Stream<AppNotification> get openedNotifications;

  Future<bool> initialize();
  Future<void> syncAuthenticatedUser(ApiClient apiClient);
  Future<void> unregisterAuthenticatedUser(ApiClient apiClient);
  AppNotification? takePendingOpenedNotification();
  void dispose();
}

class FirebasePushNotifications implements PushNotificationCoordinator {
  FirebasePushNotifications({FirebaseMessaging? messaging})
    : _injectedMessaging = messaging;

  final FirebaseMessaging? _injectedMessaging;
  final _foregroundController = StreamController<AppNotification>.broadcast();
  final _openedController = StreamController<AppNotification>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  FirebaseMessaging? _messaging;
  ApiClient? _authenticatedApiClient;
  AppNotification? _pendingOpenedNotification;
  String? _currentToken;
  bool _initialized = false;
  bool _available = false;

  @override
  Stream<AppNotification> get foregroundNotifications =>
      _foregroundController.stream;

  @override
  Stream<AppNotification> get openedNotifications => _openedController.stream;

  @override
  Future<bool> initialize() async {
    if (_initialized) return _available;
    _initialized = true;
    // ComiVerse Web is the React application. This coordinator intentionally
    // owns only the Android/iOS mobile push lifecycle.
    if (kIsWeb) return false;
    try {
      if (_injectedMessaging == null && Firebase.apps.isEmpty) {
        final options = FirebaseRuntimeOptions.currentPlatform;
        await Firebase.initializeApp(options: options);
      }
      final messaging = _injectedMessaging ?? FirebaseMessaging.instance;
      _messaging = messaging;
      await messaging.setAutoInitEnabled(true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        _foregroundController.add(notificationFromRemoteMessage(message));
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _emitOpened(notificationFromRemoteMessage(message)),
      );
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
        final apiClient = _authenticatedApiClient;
        if (apiClient != null && apiClient.hasToken) {
          unawaited(_registerToken(apiClient, token));
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _emitOpened(notificationFromRemoteMessage(initialMessage));
      }
      _available = true;
    } catch (error) {
      // The app stays fully usable before Firebase credentials are provisioned.
      // Railway/native configuration is the deployment concern, not a reason
      // to block login or reading.
      debugPrint('Push notifications unavailable: $error');
      _available = false;
    }
    return _available;
  }

  @override
  Future<void> syncAuthenticatedUser(ApiClient apiClient) async {
    _authenticatedApiClient = apiClient;
    if (!apiClient.hasToken || !await initialize()) return;
    try {
      final permission = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          !await _waitForApnsToken()) {
        debugPrint(
          'APNs token is not available yet; FCM sync will retry later.',
        );
        return;
      }
      final token = await _messaging?.getToken();
      if (token == null || token.trim().isEmpty) return;
      _currentToken = token;
      await _registerToken(apiClient, token);
    } catch (error) {
      debugPrint('Could not register this device for push: $error');
    }
  }

  Future<void> _registerToken(ApiClient apiClient, String token) {
    return apiClient.registerPushDevice(token: token, platform: _platformName);
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if ((await _messaging?.getAPNSToken())?.isNotEmpty == true) return true;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return false;
  }

  @override
  Future<void> unregisterAuthenticatedUser(ApiClient apiClient) async {
    _authenticatedApiClient = null;
    final messaging = _messaging;
    if (!_available || messaging == null) return;
    try {
      final token = _currentToken ?? await messaging.getToken();
      if (token != null && token.trim().isNotEmpty && apiClient.hasToken) {
        try {
          await apiClient.unregisterPushDevice(token);
        } catch (_) {
          // Deleting the local FCM token below also invalidates an offline
          // logout, so a stale account cannot keep receiving on this device.
        }
      }
      await messaging.deleteToken();
      _currentToken = null;
    } catch (error) {
      debugPrint('Could not clear the device push token: $error');
    }
  }

  @override
  AppNotification? takePendingOpenedNotification() {
    final pending = _pendingOpenedNotification;
    _pendingOpenedNotification = null;
    return pending;
  }

  void _emitOpened(AppNotification notification) {
    if (_openedController.hasListener) {
      _openedController.add(notification);
    } else {
      _pendingOpenedNotification = notification;
    }
  }

  @override
  void dispose() {
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
    unawaited(_foregroundController.close());
    unawaited(_openedController.close());
  }

  static String get _platformName => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
    _ => 'android',
  };

  @visibleForTesting
  static AppNotification notificationFromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;
    final id = _firstNonEmpty([
      data['notificationId'],
      message.messageId,
      DateTime.now().microsecondsSinceEpoch.toString(),
    ]);
    return AppNotification(
      id: id,
      title: _firstNonEmpty([data['title'], notification?.title, 'ComiVerse']),
      message: _firstNonEmpty([
        data['body'],
        data['message'],
        notification?.body,
        '',
      ]),
      type: _firstNonEmpty([data['type'], 'INFO']).toUpperCase(),
      actionUrl: _optional(data['actionUrl']),
      isRead: false,
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  static String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseRuntimeOptions.currentPlatform,
      );
    }
  } catch (error) {
    debugPrint('Background push initialization failed: $error');
  }
}
