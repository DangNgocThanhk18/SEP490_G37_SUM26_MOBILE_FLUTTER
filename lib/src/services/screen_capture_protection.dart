import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class ScreenCaptureProtection {
  static const bool canUserConfigure = bool.fromEnvironment(
    'COMIVERSE_DEMO_CAPTURE_CONTROL',
    defaultValue: !kReleaseMode,
  );

  static const MethodChannel _channel = MethodChannel(
    'comiverse/screen_capture_protection',
  );

  static int _activeReaders = 0;
  static bool _userProtectionEnabled = true;
  static bool? _nativeProtectionEnabled;
  static Future<void> _reconcileQueue = Future<void>.value();

  static bool get isProtectionEnabled =>
      !canUserConfigure || _userProtectionEnabled;

  static Future<void> acquire() {
    _activeReaders++;
    return _enqueueReconcile();
  }

  static Future<void> release() {
    if (_activeReaders == 0) return Future<void>.value();
    _activeReaders--;
    return _enqueueReconcile();
  }

  static Future<void> setUserProtectionEnabled(bool enabled) {
    _userProtectionEnabled = canUserConfigure ? enabled : true;
    if (_activeReaders == 0 && _nativeProtectionEnabled != true) {
      return Future<void>.value();
    }
    return _enqueueReconcile();
  }

  static bool get _hasNativeProtection =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> _enqueueReconcile() {
    if (!_hasNativeProtection) return Future<void>.value();
    final previous = _reconcileQueue;
    final next = () async {
      try {
        await previous;
        await _reconcileNativeState();
      } catch (error, stackTrace) {
        debugPrint('Unable to reconcile screen capture protection: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }();
    _reconcileQueue = next;
    return next;
  }

  static Future<void> _reconcileNativeState() async {
    while (true) {
      final shouldProtect = _activeReaders > 0 && isProtectionEnabled;
      if (_nativeProtectionEnabled == shouldProtect) return;
      final didApply = await _setProtected(shouldProtect);
      if (!didApply) return;
      _nativeProtectionEnabled = shouldProtect;
      if (shouldProtect == (_activeReaders > 0 && isProtectionEnabled)) return;
    }
  }

  static Future<bool> _setProtected(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setProtected', enabled);
      return true;
    } on MissingPluginException {
      // Unsupported platforms still receive the in-reader watermark.
    } on PlatformException catch (error, stackTrace) {
      // Copyright protection must never prevent the Reader from opening.
      debugPrint('Unable to update screen capture protection: $error');
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      // A native integration failure must not surface as an unhandled Future.
      debugPrint('Unexpected screen capture protection error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return false;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    _activeReaders = 0;
    _userProtectionEnabled = true;
    await _reconcileQueue;
    if (_hasNativeProtection) {
      final didApply = await _setProtected(false);
      _nativeProtectionEnabled = didApply ? false : null;
    } else {
      _nativeProtectionEnabled = null;
    }
    _reconcileQueue = Future<void>.value();
  }
}
