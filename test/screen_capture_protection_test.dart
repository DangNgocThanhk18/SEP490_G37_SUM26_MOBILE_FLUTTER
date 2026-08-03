import 'dart:async';

import 'package:comiverse_mobile/src/services/screen_capture_protection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('comiverse/screen_capture_protection');

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await ScreenCaptureProtection.resetForTesting();
  });

  tearDown(() async {
    await ScreenCaptureProtection.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'native capture protection stays enabled until the last reader closes',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });

      await ScreenCaptureProtection.acquire();
      await ScreenCaptureProtection.acquire();
      await ScreenCaptureProtection.release();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'setProtected');
      expect(calls.single.arguments, isTrue);

      await ScreenCaptureProtection.release();
      expect(calls, hasLength(2));
      expect(calls.last.method, 'setProtected');
      expect(calls.last.arguments, isFalse);
    },
  );

  test('a close during native enable is reconciled back to disabled', () async {
    final calls = <MethodCall>[];
    final enableStarted = Completer<void>();
    final finishEnable = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.arguments == true) {
            enableStarted.complete();
            await finishEnable.future;
          }
          return null;
        });

    final acquire = ScreenCaptureProtection.acquire();
    await enableStarted.future;
    final release = ScreenCaptureProtection.release();
    finishEnable.complete();
    await Future.wait([acquire, release]);

    expect(calls.map((call) => call.arguments), <Object?>[true, false]);
  });

  test('a failed native enable is retried by the next acquire', () async {
    final calls = <MethodCall>[];
    var shouldFail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.arguments == true && shouldFail) {
            shouldFail = false;
            throw PlatformException(code: 'temporary_failure');
          }
          return null;
        });

    await ScreenCaptureProtection.acquire();
    await ScreenCaptureProtection.acquire();

    expect(calls.where((call) => call.arguments == true), hasLength(2));

    await ScreenCaptureProtection.release();
    await ScreenCaptureProtection.release();
    expect(calls.last.arguments, isFalse);
  });

  test('disabled demo override keeps an active reader capturable', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await ScreenCaptureProtection.setUserProtectionEnabled(false);
    calls.clear();
    await ScreenCaptureProtection.acquire();

    expect(ScreenCaptureProtection.isProtectionEnabled, isFalse);
    expect(calls.where((call) => call.arguments == true), isEmpty);

    await ScreenCaptureProtection.release();
  });

  test(
    'changing the demo override outside Reader skips native calls',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });

      await ScreenCaptureProtection.setUserProtectionEnabled(false);
      await ScreenCaptureProtection.setUserProtectionEnabled(true);

      expect(calls, isEmpty);
    },
  );

  test(
    'changing demo override reconciles an active reader immediately',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });

      await ScreenCaptureProtection.acquire();
      await ScreenCaptureProtection.setUserProtectionEnabled(false);
      await ScreenCaptureProtection.setUserProtectionEnabled(true);

      expect(calls.map((call) => call.arguments), <Object?>[true, false, true]);

      await ScreenCaptureProtection.release();
    },
  );
}
