import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient base URL', () {
    test('uses an explicit URL instead of a machine-specific default', () {
      expect(
        ApiClient.resolveBaseUrl('https://api.comiverse.example/api'),
        'https://api.comiverse.example/api',
      );
    });

    test('removes the trailing slash before request paths are appended', () {
      expect(
        ApiClient.resolveBaseUrl('http://10.0.2.2:8081/api/'),
        'http://10.0.2.2:8081/api',
      );
    });

    test('uses a portable local default when no URL is provided', () {
      final uri = Uri.parse(ApiClient.resolveBaseUrl());

      expect(uri.host, anyOf('localhost', '10.0.2.2'));
      expect(uri.path, '/api');
    });
  });
}
