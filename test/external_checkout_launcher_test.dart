import 'package:comiverse_mobile/src/services/external_checkout_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only allows an HTTPS Stripe Checkout URL to leave the app', () async {
    expect(await ExternalCheckoutLauncher.open('http://checkout.stripe.com'), isFalse);
    expect(await ExternalCheckoutLauncher.open('not a URL'), isFalse);
  });
}
