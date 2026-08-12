import 'dart:convert';

import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/session_storage.dart';
import 'package:comiverse_mobile/src/models/login_device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uses the Spring explore contract for Home collections', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'http://localhost:8081/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'data': [
                {'id': 'comic-1', 'title': 'Comic one'},
              ],
            },
          }),
          200,
        );
      }),
    );

    expect(await client.getTopViewed(size: 8), hasLength(1));
    expect(await client.getRecentlyUpdated(size: 6), hasLength(1));

    expect(requests[0].url.path, '/api/comics/explore');
    expect(requests[0].url.queryParameters['sortBy'], 'Total Views');
    expect(requests[0].url.queryParameters['size'], '8');
    expect(requests[1].url.queryParameters['sortBy'], 'Recently Updated');
    expect(requests[1].url.queryParameters['size'], '6');
  });

  test(
    'uses cursor, multi-genre, status, and web sort values for Explore',
    () async {
      http.Request? captured;
      final client = ApiClient(
        baseUrl: 'http://localhost:8081/api',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'data': [
                  {'id': 'comic-1', 'title': 'Comic one'},
                ],
                'nextCursor': 'cursor-2',
                'nextReferenceId': 'comic-1',
                'hasMore': true,
              },
            }),
            200,
          );
        }),
      );

      final page = await client.exploreComics(
        cursor: 'cursor-1',
        referenceId: 'comic-0',
        genreIds: const ['action-id', 'fantasy-id'],
        publicationStatus: 'ONGOING',
        sortBy: 'Most Bookmarked',
        size: 15,
      );

      expect(page.comics.single.id, 'comic-1');
      expect(page.hasMore, isTrue);
      expect(captured?.url.path, '/api/comics/explore');
      expect(captured?.url.queryParameters, {
        'size': '15',
        'sortBy': 'Most Bookmarked',
        'cursor': 'cursor-1',
        'referenceId': 'comic-0',
        'genres': 'action-id,fantasy-id',
        'publicationStatus': 'ONGOING',
      });
    },
  );

  test(
    'fourth mobile login exposes the email OTP replacement challenge',
    () async {
      final storage = _MemorySessionStorage();
      await storage.write(
        'comiverse_offline_install_id_v1',
        'stable-installation-id-00000001',
      );
      http.Request? captured;
      final client = ApiClient(
        baseUrl: 'http://localhost:8081/api',
        sessionStorage: storage,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'deviceVerificationRequired': true,
              'deviceChallengeId': 'challenge-1',
              'deviceChallengeExpiresAt': '2026-08-12T12:05:00Z',
              'devices': [
                {
                  'id': 'device-1',
                  'deviceName': 'Old phone',
                  'platform': 'android',
                  'current': false,
                },
              ],
            }),
            202,
          );
        }),
      );

      await expectLater(
        client.login(username: 'reader', password: 'secret'),
        throwsA(
          isA<LoginDeviceVerificationRequired>()
              .having(
                (error) => error.challengeId,
                'challengeId',
                'challenge-1',
              )
              .having((error) => error.devices.length, 'devices', 1),
        ),
      );
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['deviceId'], 'stable-installation-id-00000001');
      expect(body['deviceName'], isNotEmpty);
      expect(body['platform'], anyOf('android', 'ios'));
    },
  );

  test(
    'updates the profile and notification preference API contracts',
    () async {
      final storage = _MemorySessionStorage();
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'http://localhost:8081/api',
        sessionStorage: storage,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/auth/profile')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'userId': 'reader-1',
                  'username': 'reader',
                  'email': 'reader@comiverse.test',
                  'fullName': body['fullName'],
                  'dateOfBirth': body['dateOfBirth'],
                  'bio': body['bio'],
                },
              }),
              200,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'role': 'READER',
                'availableKeys': ['SYSTEM_BROADCASTS'],
                'preferences': body['preferences'],
              },
            }),
            200,
          );
        }),
      );

      final profile = await client.updateProfile(
        fullName: 'Updated Reader',
        dateOfBirth: DateTime(2000, 1, 2),
        bio: 'Reader bio',
      );
      final preferences = await client.updateNotificationPreferences({
        'SYSTEM_BROADCASTS': false,
      });

      expect(profile.displayName, 'Updated Reader');
      expect(profile.dateOfBirth, DateTime(2000, 1, 2));
      expect(preferences.values['SYSTEM_BROADCASTS'], isFalse);
      expect(requests[0].method, 'PUT');
      expect(requests[0].url.path, '/api/auth/profile');
      expect(requests[1].url.path, '/api/notifications/preferences');
      expect(await storage.read('comiverse_user_profile'), isNotNull);
    },
  );

  test('uploads profile images with the Spring multipart contract', () async {
    http.Request? captured;
    final client = ApiClient(
      baseUrl: 'http://localhost:8081/api',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': 'https://res.cloudinary.com/comiverse/avatar.png',
          }),
          200,
        );
      }),
    );

    final url = await client.uploadImage(
      bytes: const [1, 2, 3, 4],
      fileName: 'avatar.png',
      contentType: 'image/png',
    );

    expect(url, 'https://res.cloudinary.com/comiverse/avatar.png');
    expect(captured?.method, 'POST');
    expect(captured?.url.path, '/api/upload/image');
    expect(
      captured?.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    expect(captured?.body, contains('name="file"'));
    expect(captured?.body, contains('filename="avatar.png"'));
    expect(captured?.body.toLowerCase(), contains('content-type: image/png'));
  });

  test('caches stable reads until their scope is invalidated', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'http://localhost:8081/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'id': 'comic-1', 'title': 'Cached comic'},
            ],
          }),
          200,
        );
      }),
    );

    final first = await client.getComics();
    final second = await client.getComics();

    expect(first.single.title, 'Cached comic');
    expect(second.single.title, 'Cached comic');
    expect(requests, hasLength(1));

    client.invalidateCatalogCache();
    await client.getComics();
    expect(requests, hasLength(2));
  });

  test('does not cache live notification counters', () async {
    var requestCount = 0;
    final client = ApiClient(
      baseUrl: 'http://localhost:8081/api',
      httpClient: MockClient((_) async {
        requestCount++;
        return http.Response(
          jsonEncode({'success': true, 'data': requestCount}),
          200,
        );
      }),
    );

    expect(await client.getUnreadNotificationCount(), 1);
    expect(await client.getUnreadNotificationCount(), 2);
    expect(requestCount, 2);
  });

  test('registers and unregisters the signed-in push installation', () async {
    final storage = _MemorySessionStorage();
    await storage.write('comiverse_access_token', 'access-token');
    await storage.write(
      'comiverse_user_profile',
      jsonEncode({
        'userId': 'reader-1',
        'username': 'reader',
        'email': 'reader@comiverse.test',
      }),
    );
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'http://localhost:8081/api',
      sessionStorage: storage,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'success': true}), 200);
      }),
    );
    await client.restoreSession();

    await client.registerPushDevice(
      token: 'fcm-registration-token',
      platform: 'android',
    );
    await client.unregisterPushDevice('fcm-registration-token');

    expect(requests, hasLength(2));
    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/api/notifications/devices');
    expect(requests[0].headers['authorization'], 'Bearer access-token');
    expect(jsonDecode(requests[0].body), {
      'token': 'fcm-registration-token',
      'platform': 'android',
    });
    expect(requests[1].method, 'DELETE');
    expect(jsonDecode(requests[1].body), {'token': 'fcm-registration-token'});
  });

  test('reports whether push delivery is configured and registered', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8081/api',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {'serverConfigured': true, 'registeredDeviceCount': 2},
          }),
          200,
        ),
      ),
    );

    final status = await client.getPushDeviceStatus();

    expect(status.ready, isTrue);
    expect(status.registeredDeviceCount, 2);
  });
}

class _MemorySessionStorage implements SessionStorage {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
