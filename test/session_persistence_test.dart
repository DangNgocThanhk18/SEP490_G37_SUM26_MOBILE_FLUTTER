import 'dart:convert';

import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restores and clears a persisted login session', () async {
    final storage = _MemorySessionStorage();
    const profile = UserProfile(
      username: 'reader',
      email: 'reader@comiverse.test',
      fullName: 'ComiVerse Reader',
      role: 'READER',
    );
    await storage.write('comiverse_access_token', 'access-token');
    await storage.write('comiverse_refresh_token', 'refresh-token');
    await storage.write('comiverse_user_profile', jsonEncode(profile.toJson()));

    final restoredClient = ApiClient(
      baseUrl: 'http://localhost/api',
      sessionStorage: storage,
    );
    final restoredUser = await restoredClient.restoreSession();

    expect(restoredClient.hasToken, isTrue);
    expect(restoredClient.refreshToken, 'refresh-token');
    expect(restoredUser?.displayName, 'ComiVerse Reader');

    await restoredClient.clearSession();
    final reopenedClient = ApiClient(
      baseUrl: 'http://localhost/api',
      sessionStorage: storage,
    );

    expect(await reopenedClient.restoreSession(), isNull);
    expect(reopenedClient.hasToken, isFalse);
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
