import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/app_notification.dart';
import '../models/forum.dart';
import '../models/premium_plan.dart';
import '../models/user_profile.dart';
import 'session_storage.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

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

class ApiClient {
  ApiClient({
    String? baseUrl,
    Duration timeout = const Duration(seconds: 20),
    SessionStorage? sessionStorage,
  }) : baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'http://192.168.1.6:8081/api',
           ),
       _timeout = timeout,
       _sessionStorage = sessionStorage ?? const SecureSessionStorage();

  static const _accessTokenKey = 'comiverse_access_token';
  static const _refreshTokenKey = 'comiverse_refresh_token';
  static const _profileKey = 'comiverse_user_profile';

  final String baseUrl;
  final Duration _timeout;
  final SessionStorage _sessionStorage;
  final HttpClient _httpClient = HttpClient();
  String? _token;
  String? _refreshToken;

  bool get hasToken => _token != null && _token!.isNotEmpty;
  String? get refreshToken => _refreshToken;

  Future<void> clearSession() async {
    _token = null;
    _refreshToken = null;
    await Future.wait([
      _sessionStorage.delete(_accessTokenKey),
      _sessionStorage.delete(_refreshTokenKey),
      _sessionStorage.delete(_profileKey),
    ]);
  }

  Future<UserProfile?> restoreSession() async {
    try {
      final values = await Future.wait([
        _sessionStorage.read(_accessTokenKey),
        _sessionStorage.read(_refreshTokenKey),
        _sessionStorage.read(_profileKey),
      ]);
      final token = values[0];
      if (token == null || token.trim().isEmpty) return null;

      _token = token;
      _refreshToken = values[1];
      final profileJson = values[2];
      if (profileJson != null && profileJson.trim().isNotEmpty) {
        final decoded = jsonDecode(profileJson);
        if (decoded is Map<String, dynamic>) {
          return UserProfile.fromJson(decoded);
        }
      }

      final user = await getMe();
      await _sessionStorage.write(_profileKey, jsonEncode(user.toJson()));
      return user;
    } catch (_) {
      _token = null;
      _refreshToken = null;
      return null;
    }
  }

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
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
    await Future.wait([
      _sessionStorage.write(_accessTokenKey, token),
      _sessionStorage.write(_refreshTokenKey, refreshToken),
      _sessionStorage.write(_profileKey, jsonEncode(user.toJson())),
    ]);
    return LoginResult(token: token, refreshToken: refreshToken, user: user);
  }

  Future<UserProfile> getMe() async {
    final json = await _request('GET', '/auth/me');
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read profile response.');
    }
    return UserProfile.fromJson(data);
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

  Future<List<Comic>> getComics() async {
    final json = await _request('GET', '/comics/all', authorized: false);
    final data = _unwrapData(json);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Comic.fromJson)
        .where((comic) => comic.id.isNotEmpty)
        .toList();
  }

  Future<List<Comic>> getLeaderboard({String timeframe = 'day'}) async {
    final json = await _request(
      'GET',
      '/comics/leaderboard?timeframe=${Uri.encodeQueryComponent(timeframe)}',
      authorized: false,
    );
    return _parseComicList(_unwrapData(json));
  }

  Future<List<Comic>> getTopViewed({int size = 10}) async {
    final json = await _request(
      'GET',
      '/comics/top-views?page=1&size=$size',
      authorized: false,
    );
    return _parseComicPayload(_unwrapData(json));
  }

  Future<List<Comic>> getRecentlyUpdated({int size = 10}) async {
    final json = await _request(
      'GET',
      '/comics/recently-updated?page=1&size=$size',
      authorized: false,
    );
    return _parseComicPayload(_unwrapData(json));
  }

  Future<List<Comic>> getRecommendations({int size = 10}) async {
    if (!hasToken) return getTopViewed(size: size);
    final json = await _request('GET', '/comics/recommendations?size=$size');
    return _parseComicPayload(_unwrapData(json));
  }

  Future<List<Comic>> getSavedComics() async {
    final json = await _request('GET', '/saves/my-saves');
    return _parseComicList(_unwrapData(json));
  }

  Future<List<Comic>> getLikedComics() async {
    final json = await _request('GET', '/likes/my-likes');
    return _parseComicList(_unwrapData(json));
  }

  Future<List<Comic>> getReadingHistory() async {
    final json = await _request('GET', '/reading-histories/my-history');
    return _parseComicList(_unwrapData(json));
  }

  Future<void> deleteReadingHistory(String comicId) async {
    await _request('DELETE', '/reading-histories/comic/$comicId');
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
    return _unwrapData(json) == true;
  }

  Future<bool> toggleLiked(String comicId) async {
    final json = await _request(
      'POST',
      '/likes/toggle/$comicId',
      body: const {},
    );
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

  Future<int> getUnreadNotificationCount() async {
    final json = await _request('GET', '/notifications/unread-count');
    final value = _unwrapData(json);
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
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

  Future<PremiumPlanSettings> getPremiumPlans() async {
    final json = await _request('GET', '/plans', authorized: false);
    final data = _unwrapData(json);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Cannot read premium plan settings.');
    }
    return PremiumPlanSettings.fromJson(data);
  }

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

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authorized = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    try {
      final request = await _httpClient.openUrl(method, uri).timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (authorized && hasToken) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      }
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(_timeout);
      final text = await response.transform(utf8.decoder).join();
      final decoded = text.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map<String, dynamic>
            ? (decoded['message'] ?? decoded['error'] ?? 'Request failed')
                  .toString()
            : 'Request failed';
        throw ApiException(message);
      }

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const ApiException('Unexpected backend response.');
    } on SocketException {
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
}
