import 'package:flutter/services.dart';

abstract final class ExternalCheckoutLauncher {
  static const MethodChannel _channel = MethodChannel(
    'comiverse/external_checkout',
  );

  static Future<bool> open(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.scheme != 'https') return false;
    try {
      return await _channel.invokeMethod<bool>('open', {
            'url': uri.toString(),
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
