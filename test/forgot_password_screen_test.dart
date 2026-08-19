import 'package:comiverse_mobile/src/screens/forgot_password_screen.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/theme/app_theme.dart';
import 'package:comiverse_mobile/src/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('completes the email OTP password-reset flow', (tester) async {
    final apiClient = _ForgotPasswordApiClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ForgotPasswordScreen(apiClient: apiClient),
                  ),
                ),
                child: const Text('Open reset'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open reset'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      ' reader@example.com ',
    );
    await tester.tap(find.text('Send recovery code'));
    await tester.pumpAndSettle();

    expect(apiClient.requestedEmail, ' reader@example.com ');
    expect(find.text('Recovery code'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recovery code'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'new-password-123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'new-password-123',
    );
    final resetButton = find.widgetWithText(
      PrimaryGradientButton,
      'Reset password',
    );
    await tester.ensureVisible(resetButton);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(apiClient.resetEmail, ' reader@example.com ');
    expect(apiClient.resetOtp, '123456');
    expect(apiClient.newPassword, 'new-password-123');
    expect(find.text('Open reset'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ForgotPasswordApiClient extends ApiClient {
  _ForgotPasswordApiClient() : super(baseUrl: 'http://localhost/api');

  String? requestedEmail;
  String? resetEmail;
  String? resetOtp;
  String? newPassword;

  @override
  Future<void> requestPasswordReset(String email) async {
    requestedEmail = email;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    resetEmail = email;
    resetOtp = otp;
    this.newPassword = newPassword;
  }
}
