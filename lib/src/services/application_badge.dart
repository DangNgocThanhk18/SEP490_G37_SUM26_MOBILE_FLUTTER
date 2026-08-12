import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ApplicationBadge {
  static const MethodChannel _channel = MethodChannel(
    'comiverse/application_badge',
  );

  static Future<void> setCount(int count) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('setCount', {
        'count': count < 0 ? 0 : count,
      });
    } on PlatformException catch (error) {
      debugPrint('Could not update the iOS app badge: $error');
    } on MissingPluginException {
      // Widget tests and non-iOS hosts do not register the native channel.
    }
  }
}
