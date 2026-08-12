import 'package:comiverse_mobile/src/services/application_badge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('comiverse/application_badge'),
          null,
        );
  });

  test('iOS badge channel normalizes negative unread counts to zero', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('comiverse/application_badge'),
          (call) async {
            capturedCall = call;
            return null;
          },
        );

    await ApplicationBadge.setCount(-3);

    expect(capturedCall?.method, 'setCount');
    expect(capturedCall?.arguments, {'count': 0});
  });
}
