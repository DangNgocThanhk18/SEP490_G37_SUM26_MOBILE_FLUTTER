import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/content_comment.dart';
import '../models/app_notification.dart';
import '../models/forum.dart';
import '../models/notification_preferences.dart';
import '../models/offline_download.dart';
import '../models/premium_plan.dart';
import '../models/user_profile.dart';
import 'session_storage.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class LoginResult {
  const LoginResult({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  final String token;
  final String refreshToken;
  final UserProfile user;
}

class OfflinePackageResponse {
  const OfflinePackageResponse({required this.headers, required this.bytes});

  final OfflinePackageHeaders headers;
  final Stream<List<int>> bytes;
}

class ApiClient {
  static const deployedBaseUrl =
      'https://sep490g37sum26java-production.up.railway.app/api';
  static const _catalogCacheDuration = Duration(minutes: 5);
  static const _homeCacheDuration = Duration(minutes: 2);
  static const _accountCacheDuration = Duration(seconds: 45);
  static const _forumCacheDuration = Duration(minutes: 1);
  static const _settingsCacheDuration = Duration(minutes: 10);
  static const _maximumCachedReads = 40;

  ApiClient({
    String? baseUrl,
    Duration timeout = const Duration(seconds: 20),
    SessionStorage? sessionStorage,
    http.Client? httpClient,
  }) : baseUrl = resolveBaseUrl(baseUrl),
       _timeout = timeout,
       _sessionStorage = sessionStorage ?? const SecureSessionStorage(),
       _httpClient = httpClient ?? http.Client();

  static String resolveBaseUrl([String? override]) {
    const configured = String.fromEnvironment('API_BASE_URL');
    final provided = override?.trim();
    final fromEnvironment = configured.trim();
    late final String resolved;
    if (provided?.isNotEmpty == true) {
      resolved = provided!;
    } else if (fromEnvironment.isNotEmpty) {
      resolved = fromEnvironment;
    } else {
      resolved = deployedBaseUrl;
    }
    return resolved.endsWith('/')
        ? resolved.substring(0, resolved.length - 1)
        : resolved;
  }

  static const _accessTokenKey = 'comiverse_access_token';
  static const _refreshTokenKey = 'comiverse_refresh_token';
  static const _profileKey = 'comiverse_user_profile';

  final String baseUrl;
  final Duration _timeout;
  final SessionStorage _sessionStorage;
  final http.Client _httpClient;
  String? _token;
  String? _refreshToken;
  UserProfile? _currentUser;
  String _languageCode = 'en';
  final Map<String, _CachedRead<Object>> _readCache = {};
  final Map<String, Future<Object>> _inFlightReads = {};
  int _readCacheEpoch = 0;

  bool get hasToken => _token != null && _token!.isNotEmpty;
  String? get refreshToken => _refreshToken;
  UserProfile? get currentUser => _currentUser;

  void setLanguage(String languageCode) {
    if (languageCode == 'en' || languageCode == 'vi') {
      _languageCode = languageCode;
    }
  }

  /// Drops cached Home feed reads. Pull-to-refresh uses this to always request
  /// fresh data while ordinary tab switching remains instant.
  void invalidateHomeCache() {
    _invalidateCachedReads(
      (key) => key.startsWith('home:') || key.startsWith('library:history:'),
    );
  }

  void invalidateCatalogCache() {
    _invalidateCachedReads((key) => key.startsWith('catalog:'));
  }

  void invalidateLibraryCache() {
    _invalidateCachedReads((key) => key.startsWith('library:'));
  }

  void invalidateForumCache() {
    _invalidateCachedReads((key) => key.startsWith('forum:'));
  }

  Future<void> clearSession() async {
    _clearReadCache();
    _token = null;
    _refreshToken = null;
    _currentUser = null;
    await Future.wait([
      _sessionStorage.delete(_accessTokenKey),
      _sessionStorage.delete(_refreshTokenKey),
      _sessionStorage.delete(_profileKey),
    ]);
  }

  Future<UserProfile?> restoreSession() async {
    _clearReadCache();
    try {
      final values = await Future.wait([
        _sessionStorage.read(_accessTokenKey),
        _sessionStorage.read(_refreshTokenKey),
        _sessionStorage.read(_profileKey),
      ]);
      final token = values[0];
      if (token == null || token.trim().isEmpty) {
        _currentUser = null;
        return null;
      }

      _token = token;
      _refreshToken = values[1];
      final profileJson = values[2];
      if (profileJson != null && profileJson.trim().isNotEmpty) {
        final decoded = jsonDecode(profileJson);
        if (decoded is Map<String, dynamic>) {
          _currentUser = UserProfile.fromJson(decoded);
          return _currentUser;
        }
      }

      final user = await getMe();
      await _sessionStorage.write(_profileKey, jsonEncode(user.toJson()));
      return user;
    } catch (_) {
      _token = null;
      _refreshToken = null;
      _currentUser = null;
      return null;
    }
  }

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    _clearReadCache();
    final json = await _request(
      'POST',
      '/auth/login',
      body: {'username': username, 'password': password},
      authorized: false,
    );

    final token = (json['token'] ?? '').toString();
    final refreshToken = (json['refreshToken'] ?? '').toString();
    if (token.isEmpty) {
      throw const ApiException('Backend did not return an access token.');
    }

    _token = token;
    _refreshToken = refreshToken;
    final user = await getMe();
    _currentUser = user;
    await Future.wait([
      _sessionStorage.write(_accessTokenKey, token),
      _sessionStorage.write(_refreshTokenKey, refreshToken),
      _sessionStorage.write(_profileKey, jsonEncode(user.toJson())),
    ]);
    return LoginResult(token: token, refreshToken: refreshToken, user: user);
  }

  /// Sign in with a Google ID Token obtained from the google_sign_in package.
  Future<LoginResult> loginWithGoogle(String idToken) async {
    _clearReadCache();
    final json = await _request(
      'POST',
      '/auth/google-login',
      body: {'idToken': idToken},
      authorized: false,
    );

    final token = (json['token'] ?? '').toString();
    final refreshToken = (json['refreshToken'] ?? '').toString();
    if (token.isEmpty) {
      throw const ApiException('Google sign-in did not return an access token.');
    }

    _token = token;
    _refreshToken = refreshToken;
    final user = await getMe();
    _currentUser = user;
    await Future.wait([
      _sessionStorage.write(_accessTokenKey, token),
      _sessionStorage.write(_refreshTokenKey, refreshToken),
      _sessionStorage.write(_profileKey, jsonEncode(user.toJson())),
    ]);
    return LoginResult(token: token, refreshToken: refreshToken, user: user);
  }

  /// Register a new account. After success the user must verify their email
  /// with [verifyEmail] before they can sign in.
  Future<void> register({
    required String username,
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    await _request(
      'POST',
      '/auth/register',
      body: {
        'username': username.trim(),
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
      authorized: false,
    );
  }

  /// Verify the OTP code sent to [email] after registration.
  Future<void> verifyEmail({
    required String email,
    required String otp,
  }) async {
    await _request(
      'POST',
      '/auth/verify-email',
      body: {'email': email.trim(), 'otp': otp.trim()},
      authorized: false,
    );
  }

  /// Resend the email-verification OTP to [email].
  Future<void> resendVerificationOtp(String email) async {
    await _request(
      'POST',
      '/auth/resend-verification-otp',
      body: {'email': email.trim()},
      authorized: false,
    );
  }

  Future<UserProfile> getMe() async {
    final json = await _request('GET', '/auth/me');
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read profile response.');
    }
    final user = UserProfile.fromJson(data);
    _currentUser = user;
    return user;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _request(
      'POST',
      '/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<UserProfile> updateProfile({
    required String fullName,
    String? avatarUrl,
    String? backgroundImageUrl,
    DateTime? dateOfBirth,
    String? bio,
  }) async {
    final json = await _request(
      'PUT',
      '/auth/profile',
      body: {
        'fullName': fullName.trim(),
        'avatarUrl': _trimmedOrNull(avatarUrl),
        'backgroundImageUrl': _trimmedOrNull(backgroundImageUrl),
        'dateOfBirth': dateOfBirth?.toIso8601String().split('T').first,
        'bio': _trimmedOrNull(bio),
      },
    );
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read updated profile response.');
    }
    final user = UserProfile.fromJson(data);
    _currentUser = user;
    await _sessionStorage.write(_profileKey, jsonEncode(user.toJson()));
    return user;
  }

  Future<String> uploadImage({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw const ApiException('Selected image is empty.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload/image'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Accept-Language'] = _languageCode;
    if (hasToken) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ),
    );

    const minimumUploadTimeout = Duration(seconds: 60);
    final uploadTimeout = _timeout > minimumUploadTimeout
        ? _timeout
        : minimumUploadTimeout;
    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(uploadTimeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(uploadTimeout);
      final text = utf8.decode(response.bodyBytes);
      final decoded = text.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map<String, dynamic>
            ? (decoded['message'] ?? decoded['error'] ?? 'Image upload failed')
                  .toString()
            : 'Image upload failed';
        throw ApiException(message);
      }

      if (decoded is Map<String, dynamic>) {
        final data = _unwrapData(decoded);
        if (data is String && data.trim().isNotEmpty) return data.trim();
      }
      throw const ApiException('Cannot read uploaded image response.');
    } on http.ClientException {
      throw ApiException(
        'Cannot connect to backend. Check that Spring Boot is running at $baseUrl.',
      );
    } on TimeoutException {
      throw ApiException('Request timed out while connecting to $baseUrl.');
    } on FormatException {
      throw const ApiException('Backend returned invalid JSON.');
    }
  }

  Future<List<Comic>> getComics() =>
      _cachedRead('catalog:all', _catalogCacheDuration, () async {
        final json = await _request('GET', '/comics/all', authorized: false);
        final data = _unwrapData(json);
        if (data is! List) return const <Comic>[];
        return data
            .whereType<Map<String, dynamic>>()
            .map(Comic.fromJson)
            .where((comic) => comic.id.isNotEmpty)
            .toList();
      });

  Future<List<Comic>> getLeaderboard({String timeframe = 'day'}) => _cachedRead(
    'catalog:leaderboard:$timeframe',
    _catalogCacheDuration,
    () async {
      final json = await _request(
        'GET',
        '/comics/leaderboard?timeframe=${Uri.encodeQueryComponent(timeframe)}',
        authorized: false,
      );
      return _parseComicList(_unwrapData(json));
    },
  );

  Future<List<Comic>> getTopViewed({
    int size = 10,
  }) => _cachedRead('home:top:$size', _homeCacheDuration, () async {
    final json = await _request(
      'GET',
      '/comics/explore?sortBy=${Uri.encodeQueryComponent('Total Views')}&size=$size',
      authorized: false,
    );
    return _parseComicPayload(_unwrapData(json));
  });

  Future<List<Comic>> getRecentlyUpdated({
    int size = 10,
  }) => _cachedRead('home:updated:$size', _homeCacheDuration, () async {
    final json = await _request(
      'GET',
      '/comics/explore?sortBy=${Uri.encodeQueryComponent('Recently Updated')}&size=$size',
      authorized: false,
    );
    return _parseComicPayload(_unwrapData(json));
  });

  Future<List<Comic>> getRecommendations({int size = 10}) async {
    if (!hasToken) return getTopViewed(size: size);
    return _cachedRead(
      'home:recommendations:$_viewerCacheKey:$size',
      _homeCacheDuration,
      () async {
        final json = await _request(
          'GET',
          '/comics/recommendations?size=$size',
        );
        return _parseComicPayload(_unwrapData(json));
      },
    );
  }

  Future<List<Comic>> getSavedComics() => _cachedRead(
    'library:saved:$_viewerCacheKey',
    _accountCacheDuration,
    () async {
      final json = await _request('GET', '/saves/my-saves');
      return _parseComicList(_unwrapData(json));
    },
  );

  Future<List<Comic>> getLikedComics() => _cachedRead(
    'library:liked:$_viewerCacheKey',
    _accountCacheDuration,
    () async {
      final json = await _request('GET', '/likes/my-likes');
      return _parseComicList(_unwrapData(json));
    },
  );

  Future<List<Comic>> getReadingHistory() => _cachedRead(
    'library:history:$_viewerCacheKey',
    _accountCacheDuration,
    () async {
      final json = await _request('GET', '/reading-histories/my-history');
      return _parseComicList(_unwrapData(json));
    },
  );

  Future<void> deleteReadingHistory(String comicId) async {
    await _request('DELETE', '/reading-histories/comic/$comicId');
    invalidateHomeCache();
    invalidateLibraryCache();
  }

  Future<bool> checkSaved(String comicId) async {
    final json = await _request('GET', '/saves/check/$comicId');
    return _unwrapData(json) == true;
  }

  Future<bool> checkLiked(String comicId) async {
    final json = await _request('GET', '/likes/check/$comicId');
    return _unwrapData(json) == true;
  }

  Future<bool> toggleSaved(String comicId) async {
    final json = await _request(
      'POST',
      '/saves/toggle/$comicId',
      body: const {},
    );
    invalidateLibraryCache();
    return _unwrapData(json) == true;
  }

  Future<bool> toggleLiked(String comicId) async {
    final json = await _request(
      'POST',
      '/likes/toggle/$comicId',
      body: const {},
    );
    invalidateLibraryCache();
    return _unwrapData(json) == true;
  }

  Future<Set<String>> getReadChapterIds(String comicId) async {
    final json = await _request('GET', '/reading-histories/chapters/$comicId');
    final data = _unwrapData(json);
    if (data is! List) return const {};
    return data.map((item) => item.toString()).toSet();
  }

  Future<List<AppNotification>> getNotifications() async {
    final json = await _request('GET', '/notifications');
    final data = _unwrapData(json);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _request('PUT', '/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _request('PUT', '/notifications/read-all');
  }

  Future<NotificationPreferences> getNotificationPreferences() async {
    final json = await _request('GET', '/notifications/preferences');
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read notification preferences.');
    }
    return NotificationPreferences.fromJson(data);
  }

  Future<NotificationPreferences> updateNotificationPreferences(
    Map<String, bool> preferences,
  ) async {
    final json = await _request(
      'PUT',
      '/notifications/preferences',
      body: {'preferences': preferences},
    );
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read notification preferences.');
    }
    return NotificationPreferences.fromJson(data);
  }

  Future<int> getUnreadNotificationCount() async {
    final json = await _request('GET', '/notifications/unread-count');
    final value = _unwrapData(json);
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> registerPushDevice({
    required String token,
    required String platform,
  }) async {
    await _request(
      'POST',
      '/notifications/devices',
      body: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterPushDevice(String token) async {
    await _request('DELETE', '/notifications/devices', body: {'token': token});
  }

  Future<List<ForumThread>> getForumThreads() => _cachedRead(
    'forum:threads:$_viewerCacheKey',
    _forumCacheDuration,
    () async {
      final json = await _request(
        'GET',
        '/forum-threads/all',
        authorized: hasToken,
      );
      final data = _unwrapData(json);
      if (data is! List) return const <ForumThread>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ForumThread.fromJson)
          .where((thread) => thread.id.isNotEmpty)
          .toList();
    },
  );

  Future<ForumThread> createForumThread({
    required String title,
    required String category,
    required String content,
  }) async {
    final json = await _request(
      'POST',
      '/forum-threads',
      body: {'title': title, 'category': category, 'content': content},
    );
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read discussion thread.');
    }
    invalidateForumCache();
    return ForumThread.fromJson(data);
  }

  Future<ForumThread> getForumThread(String threadId) async {
    final json = await _request(
      'GET',
      '/forum-threads/${Uri.encodeComponent(threadId)}',
      authorized: hasToken,
    );
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read discussion thread.');
    }
    return ForumThread.fromJson(data);
  }

  Future<List<ForumComment>> getForumComments(String threadId) async {
    final json = await _request(
      'GET',
      '/forum-threads/${Uri.encodeComponent(threadId)}/comments',
      authorized: hasToken,
    );
    final data = _unwrapData(json);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ForumComment.fromJson)
        .where((comment) => comment.id.isNotEmpty)
        .toList();
  }

  Future<ForumComment> createForumComment({
    required String threadId,
    required String content,
    String? parentId,
  }) async {
    final json = await _request(
      'POST',
      '/forum-threads/${Uri.encodeComponent(threadId)}/comments',
      body: {
        'content': content.trim(),
        if (parentId?.trim().isNotEmpty == true) 'parentId': parentId!.trim(),
      },
    );
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read the created forum reply.');
    }
    invalidateForumCache();
    return ForumComment.fromJson(data);
  }

  Future<PremiumPlanSettings> getPremiumPlans() =>
      _cachedRead('settings:premium-plans', _settingsCacheDuration, () async {
        final json = await _request('GET', '/plans', authorized: false);
        final data = _unwrapData(json);
        if (data is! Map<String, dynamic>) {
          throw const ApiException('Cannot read premium plan settings.');
        }
        return PremiumPlanSettings.fromJson(data);
      });

  Future<void> upgradePlan(String planType) async {
    await _request('POST', '/plans/upgrade', body: {'planType': planType});
  }

  Future<Comic> getComicDetail(String id) async {
    final json = await _request('GET', '/comics/$id', authorized: false);
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read comic detail.');
    }
    return Comic.fromJson(data);
  }

  Future<List<ChapterLite>> getChapters(String comicId) async {
    final json = await _request(
      'GET',
      '/chapters/comic/$comicId',
      authorized: false,
    );
    final data = _unwrapData(json);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChapterLite.fromJson)
        .where((chapter) => chapter.id.isNotEmpty)
        .toList();
  }

  Future<ChapterDetail> getChapterDetail(String chapterId) async {
    final json = await _request(
      'GET',
      '/chapters/detail/$chapterId',
      authorized: hasToken,
    );
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read chapter detail.');
    }
    return ChapterDetail.fromJson(data);
  }

  /// Every language a comic has at least one translated chapter in — used
  /// to build the reader's language picker before the reader even knows
  /// which chapter they'll open.
  Future<List<String>> getComicTranslationLanguages(String comicId) async {
    final json = await _request(
      'GET',
      '/comics/$comicId/translation-languages',
      authorized: false,
    );
    final data = _unwrapData(json);
    if (data is! List) return const [];
    return data.map((item) => item.toString()).toList();
  }

  /// Every translation available for a specific chapter (language + its
  /// per-page bubbles). May be a subset of getComicTranslationLanguages
  /// if some languages haven't reached this particular chapter yet.
  Future<List<ChapterTranslation>> getChapterTranslations(
    String chapterId,
  ) async {
    final json = await _request(
      'GET',
      '/chapters/$chapterId/translations',
      authorized: false,
    );
    final data = _unwrapData(json);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChapterTranslation.fromJson)
        .toList();
  }

  Future<ContentCommentPage> getContentComments({
    required ContentCommentTarget target,
    required String targetId,
    String? parentId,
    int page = 1,
    int size = 10,
  }) async {
    final resource = target == ContentCommentTarget.comic
        ? 'comics'
        : 'chapters';
    final targetKey = target == ContentCommentTarget.comic
        ? 'comicId'
        : 'chapterId';
    final query = Uri(
      queryParameters: {
        targetKey: targetId,
        if (parentId?.trim().isNotEmpty == true) 'parentId': parentId!.trim(),
        'page': '$page',
        'size': '$size',
      },
    ).query;
    final json = await _request(
      'GET',
      '/comments/$resource?$query',
      authorized: hasToken,
    );
    final data = _unwrapData(json);
    final items = data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(ContentComment.fromJson)
              .where((comment) => comment.id.isNotEmpty)
              .toList()
        : <ContentComment>[];
    final metadata = json['metadata'];
    return ContentCommentPage(
      items: items,
      page: _asInt(
        metadata is Map<String, dynamic> ? metadata['page'] : null,
        fallback: page,
      ),
      pageSize: _asInt(
        metadata is Map<String, dynamic> ? metadata['size'] : null,
        fallback: size,
      ),
      totalElements: _asInt(
        metadata is Map<String, dynamic> ? metadata['totalElements'] : null,
        fallback: items.length,
      ),
      totalPages: _asInt(
        metadata is Map<String, dynamic> ? metadata['totalPages'] : null,
        fallback: items.isEmpty ? 0 : 1,
      ),
    );
  }

  Future<ContentComment> createContentComment({
    required ContentCommentTarget target,
    required String targetId,
    required String content,
    String? parentId,
    String? mentionId,
  }) async {
    final resource = target == ContentCommentTarget.comic
        ? 'comics'
        : 'chapters';
    final targetKey = target == ContentCommentTarget.comic
        ? 'comicId'
        : 'chapterId';
    final json = await _request(
      'POST',
      '/comments/$resource',
      body: {
        targetKey: targetId,
        'content': content.trim(),
        if (parentId?.trim().isNotEmpty == true) 'parentId': parentId!.trim(),
        if (mentionId?.trim().isNotEmpty == true)
          'mentionId': mentionId!.trim(),
      },
    );
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read the created comment.');
    }
    return ContentComment.fromJson(data);
  }

  Future<void> deleteContentComment({
    required ContentCommentTarget target,
    required String commentId,
  }) async {
    final resource = target == ContentCommentTarget.comic
        ? 'comics'
        : 'chapters';
    await _request(
      'DELETE',
      '/comments/$resource/${Uri.encodeComponent(commentId)}',
    );
  }

  Future<OfflineDeviceChallenge> createOfflineDeviceChallenge({
    required String deviceId,
    required String deviceName,
    required String devicePublicKey,
  }) async {
    final json = await _request(
      'POST',
      '/downloads/devices/challenges',
      body: {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'devicePublicKey': devicePublicKey,
      },
    );
    try {
      return OfflineDeviceChallenge.fromJson(json);
    } on FormatException {
      throw const ApiException('Cannot read the offline device challenge.');
    }
  }

  Future<OfflineDeviceEnrollment> enrollOfflineDevice({
    required String challengeId,
    required String signature,
  }) async {
    final json = await _request(
      'POST',
      '/downloads/devices',
      body: {'challengeId': challengeId, 'signature': signature},
    );
    try {
      return OfflineDeviceEnrollment.fromJson(json);
    } on FormatException {
      throw const ApiException('Cannot read the offline device enrollment.');
    }
  }

  Future<List<OfflineRegisteredDevice>> getOfflineDevices() async {
    final json = await _request('GET', '/downloads/devices');
    final data = _unwrapData(json);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(OfflineRegisteredDevice.fromJson)
        .toList(growable: false);
  }

  Future<void> revokeOfflineDevice(String deviceKeyId) => _request(
    'DELETE',
    '/downloads/devices/${Uri.encodeComponent(deviceKeyId)}',
  ).then((_) {});

  Future<OfflinePackageResponse> downloadOfflineChapter({
    required String chapterId,
    required String deviceKeyId,
  }) async {
    if (!hasToken) {
      throw const ApiException(
        'Sign in before downloading a chapter.',
        statusCode: 401,
      );
    }
    final uri = Uri.parse(
      '$baseUrl/downloads/chapters/${Uri.encodeComponent(chapterId)}',
    );
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/vnd.comiverse.cvpack'
      ..headers['Accept-Language'] = _languageCode
      ..headers['Authorization'] = 'Bearer $_token'
      ..body = jsonEncode({'deviceKeyId': deviceKeyId});
    try {
      // The backend creates, encrypts, and hashes the package before sending
      // headers. Large chapters legitimately need longer than an ordinary API
      // read, but a stalled body still fails via the inactivity timeout below.
      final response = await _httpClient
          .send(request)
          .timeout(const Duration(minutes: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decoder.bind(response.stream).join();
        var message = 'Offline chapter download failed.';
        String? code;
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            message = (decoded['message'] ?? decoded['error'] ?? message)
                .toString();
            final errors = decoded['errors'];
            code =
                (decoded['code'] ??
                        (errors is Map<String, dynamic>
                            ? errors['code']
                            : null))
                    ?.toString();
          }
        } catch (_) {}
        throw ApiException(
          message,
          statusCode: response.statusCode,
          code: code,
        );
      }
      if ((response.headers['content-type'] ?? '').toLowerCase().startsWith(
            'application/vnd.comiverse.cvpack',
          ) ==
          false) {
        throw const ApiException(
          'Backend returned an invalid offline package content type.',
        );
      }
      String requiredHeader(String name) {
        final value = response.headers[name.toLowerCase()]?.trim() ?? '';
        if (value.isEmpty) {
          throw ApiException('Backend did not return the $name header.');
        }
        return value;
      }

      final expiresAt = DateTime.tryParse(
        requiredHeader('X-Comiverse-License-Expires-At'),
      );
      final serverTime = DateTime.tryParse(
        requiredHeader('X-Comiverse-Server-Time'),
      );
      if (expiresAt == null || serverTime == null) {
        throw const ApiException(
          'Backend returned an invalid offline license time.',
        );
      }
      return OfflinePackageResponse(
        headers: OfflinePackageHeaders(
          licenseToken: requiredHeader('X-Comiverse-License'),
          wrappedContentKey: requiredHeader('X-Comiverse-Wrapped-Key'),
          keyAlgorithm: requiredHeader('X-Comiverse-Key-Algorithm'),
          expiresAt: expiresAt.toUtc(),
          serverTime: serverTime.toUtc(),
          packageSha256: requiredHeader(
            'X-Comiverse-Package-Sha256',
          ).toLowerCase(),
          manifestSha256: requiredHeader(
            'X-Comiverse-Manifest-Sha256',
          ).toLowerCase(),
          packageId: requiredHeader('X-Comiverse-Package-Id'),
          deviceKeyId: requiredHeader('X-Comiverse-Device-Key-Id'),
          formatVersion:
              int.tryParse(requiredHeader('X-Comiverse-Format-Version')) ?? 0,
          signingKeyId: requiredHeader('X-Comiverse-Signing-Key-Id'),
        ),
        bytes: response.stream.timeout(
          const Duration(seconds: 45),
          onTimeout: (sink) {
            sink.addError(
              TimeoutException('Offline package download stalled.'),
            );
            sink.close();
          },
        ),
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot connect to backend. Check that Spring Boot is running at $baseUrl.',
      );
    } on TimeoutException {
      throw ApiException('Request timed out while connecting to $baseUrl.');
    }
  }

  Future<OfflineLicenseRenewal> renewOfflineLicense({
    required String packageId,
    required String deviceKeyId,
  }) async {
    final json = await _request(
      'POST',
      '/downloads/packages/${Uri.encodeComponent(packageId)}/licenses',
      body: {'deviceKeyId': deviceKeyId},
    );
    try {
      return OfflineLicenseRenewal.fromJson(json);
    } on FormatException {
      throw const ApiException('Cannot read the renewed offline license.');
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authorized = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    try {
      final request = http.Request(method, uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json';
      request.headers['Accept-Language'] = _languageCode;
      if (authorized && hasToken) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(_timeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(_timeout);
      final text = utf8.decode(response.bodyBytes);
      final decoded = text.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map<String, dynamic>
            ? (decoded['message'] ?? decoded['error'] ?? 'Request failed')
                  .toString()
            : 'Request failed';
        throw ApiException(
          message,
          statusCode: response.statusCode,
          code: decoded is Map<String, dynamic>
              ? (decoded['code'] ??
                        (decoded['errors'] is Map<String, dynamic>
                            ? (decoded['errors']
                                  as Map<String, dynamic>)['code']
                            : null))
                    ?.toString()
              : null,
        );
      }

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const ApiException('Unexpected backend response.');
    } on http.ClientException {
      throw ApiException(
        'Cannot connect to backend. Check that Spring Boot is running at $baseUrl.',
      );
    } on TimeoutException {
      throw ApiException('Request timed out while connecting to $baseUrl.');
    } on FormatException {
      throw const ApiException('Backend returned invalid JSON.');
    }
  }

  Object? _unwrapData(Map<String, dynamic> json) {
    if (json.containsKey('data')) return json['data'];
    return json;
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<Comic> _parseComicList(Object? data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Comic.fromJson)
        .where((comic) => comic.id.isNotEmpty)
        .toList();
  }

  List<Comic> _parseComicPayload(Object? data) {
    if (data is List) return _parseComicList(data);
    if (data is Map<String, dynamic>) {
      return _parseComicList(data['data']);
    }
    return const [];
  }

  String get _viewerCacheKey {
    final token = _token;
    if (token == null || token.isEmpty) return 'guest';
    return token.hashCode.toUnsigned(32).toRadixString(16);
  }

  Future<T> _cachedRead<T extends Object>(
    String key,
    Duration duration,
    Future<T> Function() loader,
  ) {
    final now = DateTime.now();
    final cached = _readCache[key];
    if (cached != null) {
      if (now.difference(cached.storedAt) <= duration) {
        return Future.value(cached.value as T);
      }
      _readCache.remove(key);
    }

    final inFlight = _inFlightReads[key];
    if (inFlight != null) {
      return inFlight.then((value) => value as T);
    }

    final epoch = _readCacheEpoch;
    final future = _loadAndCache(key, epoch, loader);
    _inFlightReads[key] = future;
    return future;
  }

  Future<T> _loadAndCache<T extends Object>(
    String key,
    int epoch,
    Future<T> Function() loader,
  ) async {
    try {
      final value = await loader();
      if (epoch == _readCacheEpoch) {
        if (!_readCache.containsKey(key) &&
            _readCache.length >= _maximumCachedReads) {
          var oldestKey = _readCache.keys.first;
          for (final entry in _readCache.entries) {
            if (entry.value.storedAt.isBefore(
              _readCache[oldestKey]!.storedAt,
            )) {
              oldestKey = entry.key;
            }
          }
          _readCache.remove(oldestKey);
        }
        _readCache[key] = _CachedRead<Object>(
          value: value,
          storedAt: DateTime.now(),
        );
      }
      return value;
    } finally {
      // An invalidation clears the in-flight map and advances the epoch. Do
      // not let an older request remove a newer request for the same key.
      if (epoch == _readCacheEpoch) _inFlightReads.remove(key);
    }
  }

  void _invalidateCachedReads(bool Function(String key) matches) {
    _readCache.removeWhere((key, _) => matches(key));
    // In-flight HTTP requests cannot be cancelled, but advancing the epoch
    // prevents their result from repopulating stale cache entries.
    _readCacheEpoch++;
    _inFlightReads.clear();
  }

  void _clearReadCache() {
    _readCacheEpoch++;
    _readCache.clear();
    _inFlightReads.clear();
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _CachedRead<T extends Object> {
  const _CachedRead({required this.value, required this.storedAt});

  final T value;
  final DateTime storedAt;
}
