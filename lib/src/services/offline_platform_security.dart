import 'package:flutter/services.dart';

class OfflinePlatformIdentity {
  const OfflinePlatformIdentity({
    required this.publicKeyX509Base64,
    required this.publicKeySha256,
    this.deviceName = 'Mobile device',
  });

  final String publicKeyX509Base64;
  final String publicKeySha256;
  final String deviceName;
}

class OfflinePlatformClock {
  const OfflinePlatformClock({
    required this.elapsedRealtimeMillis,
    required this.bootCount,
  });

  final int elapsedRealtimeMillis;
  final int bootCount;
}

abstract interface class OfflinePlatformSecurity {
  Future<bool> isSupported();

  Future<OfflinePlatformIdentity> getOrCreateIdentity(String accountScope);

  Future<Uint8List> signEnrollmentChallenge({
    required String accountScope,
    required Uint8List challenge,
  });

  Future<Uint8List> decryptPage({
    required String accountScope,
    required String wrappedContentKey,
    required String keyAlgorithm,
    required Uint8List nonce,
    required Uint8List encryptedPage,
    required Uint8List aad,
  });

  Future<OfflinePlatformClock> readClock();

  Future<void> clearTransientKeys();

  Future<void> deleteIdentity(String accountScope);
}

class NativeOfflinePlatformSecurity implements OfflinePlatformSecurity {
  const NativeOfflinePlatformSecurity({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'comiverse/offline_security';
  final MethodChannel _channel;

  @override
  Future<bool> isSupported() async =>
      await _channel.invokeMethod<bool>('isSupported') ?? false;

  @override
  Future<OfflinePlatformIdentity> getOrCreateIdentity(
    String accountScope,
  ) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getOrCreateIdentity',
      {'accountScope': accountScope},
    );
    final publicKey = result?['publicKey']?.toString() ?? '';
    final fingerprint = result?['publicKeySha256']?.toString() ?? '';
    if (publicKey.isEmpty || fingerprint.isEmpty) {
      throw PlatformException(
        code: 'identity_unavailable',
        message: 'The device security provider did not return an identity.',
      );
    }
    return OfflinePlatformIdentity(
      publicKeyX509Base64: publicKey,
      publicKeySha256: fingerprint.toLowerCase(),
      deviceName: result?['deviceName']?.toString() ?? 'Mobile device',
    );
  }

  @override
  Future<Uint8List> signEnrollmentChallenge({
    required String accountScope,
    required Uint8List challenge,
  }) async {
    final result = await _channel.invokeMethod<Uint8List>(
      'signEnrollmentChallenge',
      {'accountScope': accountScope, 'challenge': challenge},
    );
    if (result == null || result.isEmpty) {
      throw PlatformException(
        code: 'signing_failed',
        message: 'The device security provider did not sign the challenge.',
      );
    }
    return Uint8List.fromList(result);
  }

  @override
  Future<Uint8List> decryptPage({
    required String accountScope,
    required String wrappedContentKey,
    required String keyAlgorithm,
    required Uint8List nonce,
    required Uint8List encryptedPage,
    required Uint8List aad,
  }) async {
    final result = await _channel.invokeMethod<Uint8List>('decryptPage', {
      'accountScope': accountScope,
      'wrappedContentKey': wrappedContentKey,
      'keyAlgorithm': keyAlgorithm,
      'nonce': nonce,
      'encryptedPage': encryptedPage,
      'aad': aad,
    });
    if (result == null || result.isEmpty) {
      throw PlatformException(
        code: 'decryption_failed',
        message: 'The offline page could not be decrypted.',
      );
    }
    // Platform messages expose typed-data views backed by an immutable engine
    // buffer. Offline preparation wipes plaintext after caching, so keep an
    // owned mutable copy instead of leaking the codec's view downstream.
    return Uint8List.fromList(result);
  }

  @override
  Future<OfflinePlatformClock> readClock() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('readClock');
    final elapsed = result?['elapsedRealtimeMillis'];
    final bootCount = result?['bootCount'];
    if (elapsed is! num || bootCount is! num) {
      throw PlatformException(
        code: 'trusted_clock_unavailable',
        message: 'A trusted device clock is unavailable.',
      );
    }
    return OfflinePlatformClock(
      elapsedRealtimeMillis: elapsed.toInt(),
      bootCount: bootCount.toInt(),
    );
  }

  @override
  Future<void> clearTransientKeys() =>
      _channel.invokeMethod('clearTransientKeys');

  @override
  Future<void> deleteIdentity(String accountScope) =>
      _channel.invokeMethod('deleteIdentity', {'accountScope': accountScope});
}
