import 'package:comiverse_mobile/src/l10n/app_localizations.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const secretApiUrl = 'https://private-api.example.com/api';

  test('network failures never expose the configured API URL', () async {
    final client = ApiClient(
      baseUrl: secretApiUrl,
      httpClient: MockClient((request) async {
        throw http.ClientException('Connection refused', request.url);
      }),
    );

    await expectLater(
      client.getComics(),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.code,
              'code',
              ApiException.networkUnavailableCode,
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains(secretApiUrl)),
            ),
      ),
    );
  });

  test('timeouts use a retryable message without technical details', () async {
    final client = ApiClient(
      baseUrl: secretApiUrl,
      timeout: const Duration(milliseconds: 1),
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.getComics(),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.code,
              'code',
              ApiException.requestTimeoutCode,
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains(secretApiUrl)),
            ),
      ),
    );
  });

  test('user-facing mapper hides URLs from legacy and server errors', () {
    const localizations = AppLocalizations(Locale('en'));

    final legacyMessage = localizations.errorMessage(
      const ApiException(
        'Cannot connect to backend. Check that Spring Boot is running at '
        '$secretApiUrl.',
      ),
    );
    final serverMessage = localizations.errorMessage(
      const ApiException(
        'Upstream failed at $secretApiUrl/internal/health',
        statusCode: 503,
      ),
    );

    expect(
      legacyMessage,
      'No internet connection. Check your network and try again.',
    );
    expect(
      serverMessage,
      'The server is temporarily unavailable. Please try again later.',
    );
    expect(legacyMessage, isNot(contains(secretApiUrl)));
    expect(serverMessage, isNot(contains(secretApiUrl)));
  });

  test(
    'validation messages remain useful and network errors are localized',
    () {
      const english = AppLocalizations(Locale('en'));
      const vietnamese = AppLocalizations(Locale('vi'));

      expect(
        english.errorMessage(
          const ApiException('Invalid verification code.', statusCode: 400),
        ),
        'Invalid verification code.',
      );
      expect(
        vietnamese.errorMessage(
          const ApiException(
            'No internet connection. Check your network and try again.',
            code: ApiException.networkUnavailableCode,
          ),
        ),
        'Không có kết nối Internet. Hãy kiểm tra mạng và thử lại.',
      );
    },
  );
}
