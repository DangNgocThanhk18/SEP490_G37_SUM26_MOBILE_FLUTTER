import 'dart:convert';

import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/session_storage.dart';
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
