import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:comiverse_mobile/src/models/offline_download.dart';
import 'package:comiverse_mobile/src/models/user_profile.dart';
import 'package:comiverse_mobile/src/services/api_client.dart';
import 'package:comiverse_mobile/src/services/offline_download_service.dart';
import 'package:comiverse_mobile/src/services/offline_decrypted_cache_contract.dart';
import 'package:comiverse_mobile/src/services/offline_platform_security.dart';
import 'package:comiverse_mobile/src/services/session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('native offline byte ownership', () {
    const channel = MethodChannel('comiverse/offline_security_test');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('copies immutable Android decryption results before wiping', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'decryptPage');
            return Uint8List.fromList([1, 2, 3]).asUnmodifiableView();
          });
      const security = NativeOfflinePlatformSecurity(channel: channel);

      final bytes = await security.decryptPage(
        accountScope: 'user-1',
        wrappedContentKey: 'wrapped-key',
        keyAlgorithm: 'RSA-OAEP-SHA256-MGF1SHA1',
        nonce: Uint8List(12),
        encryptedPage: Uint8List.fromList([4, 5, 6]),
        aad: Uint8List.fromList([7, 8]),
      );

      expect(() => bytes.fillRange(0, bytes.length, 0), returnsNormally);
      expect(bytes, everyElement(0));
    });

    test('copies immutable Android enrollment signatures', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'signEnrollmentChallenge');
            return Uint8List.fromList([9, 8, 7]).asUnmodifiableView();
          });
      const security = NativeOfflinePlatformSecurity(channel: channel);

      final signature = await security.signEnrollmentChallenge(
        accountScope: 'user-1',
        challenge: Uint8List.fromList([1]),
      );

      expect(() => signature[0] = 0, returnsNormally);
      expect(signature.first, 0);
    });
  });

  group('offline license signature', () {
    test('accepts standard Ed25519 X.509 SPKI and rejects tampering', () async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      const spkiPrefix = <int>[
        0x30,
        0x2a,
        0x30,
        0x05,
        0x06,
        0x03,
        0x2b,
        0x65,
        0x70,
        0x03,
        0x21,
        0x00,
      ];
      final verifier = Ed25519OfflineLicenseVerifier(
        publicKey: base64Encode([...spkiPrefix, ...publicKey.bytes]),
        signingKeyId: 'k1',
      );
      final payload = _claimsJson();
      final headerPart = _b64(
        utf8.encode(jsonEncode({'alg': 'EdDSA', 'typ': 'JWT', 'kid': 'k1'})),
      );
      final payloadPart = _b64(utf8.encode(jsonEncode(payload)));
      final input = '$headerPart.$payloadPart';
      final signature = await algorithm.sign(
        utf8.encode(input),
        keyPair: keyPair,
      );
      final token = '$input.${_b64(signature.bytes)}';

      final claims = await verifier.verify(token);
      expect(claims.packageId, 'package-1');
      expect(claims.signingKeyId, 'k1');
      expect(
        claims.aadForPage(1, 'a' * 64),
        'CVPK1|package-1|user-1|chapter-1|${'b' * 64}|revision-1|1|${'a' * 64}',
      );

      final wrongKidVerifier = Ed25519OfflineLicenseVerifier(
        publicKey: base64Encode([...spkiPrefix, ...publicKey.bytes]),
        signingKeyId: 'different-key',
      );
      await expectLater(
        wrongKidVerifier.verify(token),
        throwsA(isA<OfflineDownloadException>()),
      );

      final replacement = token.endsWith('A') ? 'B' : 'A';
      await expectLater(
        verifier.verify('${token.substring(0, token.length - 1)}$replacement'),
        throwsA(
          isA<OfflineDownloadException>().having(
            (error) => error.code,
            'code',
            'invalid_license',
          ),
        ),
      );
    });
  });

  group('CVPK1 manifest framing', () {
    test('parses big-endian header and rejects overlapping page ranges', () {
      final valid = _manifestJson([
        _pageJson(page: 1, offset: 0),
        _pageJson(page: 2, offset: 32),
      ]);
      final manifestBytes = utf8.encode(jsonEncode(valid));
      final header = _header(manifestBytes.length);
      final parsed = CvPackManifest.parse(
        header: header,
        manifestBytes: manifestBytes,
        packageLength: 9 + manifestBytes.length + 64,
      );
      expect(parsed.pageCount, 2);
      expect(parsed.payloadOffset, 9 + manifestBytes.length);

      final overlapping = _manifestJson([
        _pageJson(page: 1, offset: 0),
        _pageJson(page: 2, offset: 8),
      ]);
      final overlapBytes = utf8.encode(jsonEncode(overlapping));
      expect(
        () => CvPackManifest.parse(
          header: _header(overlapBytes.length),
          manifestBytes: overlapBytes,
          packageLength: 9 + overlapBytes.length + 64,
        ),
        throwsA(isA<OfflineDownloadException>()),
      );
    });

    test('rejects oversized manifest length before reading payload', () {
      final length = CvPackManifest.maximumManifestBytes + 1;
      expect(
        () => CvPackManifest.parse(
          header: _header(length),
          manifestBytes: const [],
          packageLength: length + 9,
        ),
        throwsA(isA<OfflineDownloadException>()),
      );
    });
  });

  group('trusted offline clock', () {
    late _MemoryStorage storage;
    late _FakePlatformSecurity platform;
    late OfflineDownloadService service;
    late OfflineLicenseClaims claims;
    late OfflineDownloadEntry entry;
    final serverTime = DateTime.utc(2026, 8, 4, 12);

    setUp(() async {
      storage = _MemoryStorage();
      platform = _FakePlatformSecurity(
        clock: const OfflinePlatformClock(
          elapsedRealtimeMillis: 1000,
          bootCount: 5,
        ),
      );
      claims = _claims(
        serverTime: serverTime,
        offlineUntil: serverTime.add(const Duration(days: 7)),
      );
      service = OfflineDownloadService(
        apiClient: ApiClient(),
        secureStorage: storage,
        platformSecurity: platform,
        decryptedPageCache: _MemoryDecryptedCache(),
        licenseVerifier: _StaticVerifier({'license': claims}),
      );
      await service.bindAccount(
        const UserProfile(
          userId: 'user-1',
          username: 'reader',
          email: 'reader@example.com',
        ),
      );
      entry = _entry(
        offlineUntil: claims.offlineUntil,
        licenseToken: 'license',
      );
      await service.anchorTrustedTimeForTesting(serverTime);
    });

    test(
      'advances from elapsedRealtime instead of editable wall time',
      () async {
        platform.clock = const OfflinePlatformClock(
          elapsedRealtimeMillis: 61000,
          bootCount: 5,
        );
        final estimated = await service.validateTrustedTimeForTesting(entry);
        expect(estimated, serverTime.add(const Duration(minutes: 1)));
      },
    );

    test('requires online verification after reboot', () async {
      platform.clock = const OfflinePlatformClock(
        elapsedRealtimeMillis: 100,
        bootCount: 6,
      );
      await expectLater(
        service.validateTrustedTimeForTesting(entry),
        throwsA(
          isA<OfflineDownloadException>().having(
            (error) => error.requiresOnline,
            'requiresOnline',
            true,
          ),
        ),
      );
    });

    test('does not trust a later expiry stored in local metadata', () async {
      platform.clock = const OfflinePlatformClock(
        elapsedRealtimeMillis: 2000,
        bootCount: 5,
      );
      final tampered = _entry(
        offlineUntil: serverTime.add(const Duration(days: 365)),
        licenseToken: 'license',
      );
      await expectLater(
        service.validateTrustedTimeForTesting(tampered),
        throwsA(isA<OfflineDownloadException>()),
      );
    });
  });
}

Map<String, dynamic> _claimsJson() => {
  'iss': 'comiverse-api',
  'aud': 'comiverse-android',
  'jti': 'license-1',
  'sub': 'user-1',
  'userId': 'user-1',
  'chapterId': 'chapter-1',
  'comicId': 'comic-1',
  'packageId': 'package-1',
  'deviceKeyId': 'device-key-1',
  'deviceIdHash': 'c' * 64,
  'deviceKeySha256': 'b' * 64,
  'contentRevision': 'revision-1',
  'manifestSha256': 'd' * 64,
  'packageSha256': 'e' * 64,
  'packageSize': 1234,
  'wrappedKeySha256': 'f' * 64,
  'keyAlgorithm': 'RSA-OAEP-SHA256-MGF1SHA1',
  'formatVersion': 1,
  'iat': 1785844800,
  'nbf': 1785844770,
  'exp': 1786449600,
  'serverTime': '2026-08-04T12:00:00Z',
  'offlineUntil': '2026-08-11T12:00:00Z',
};

OfflineLicenseClaims _claims({
  required DateTime serverTime,
  required DateTime offlineUntil,
}) => OfflineLicenseClaims.fromJson({
  ..._claimsJson(),
  'iat': serverTime.millisecondsSinceEpoch ~/ 1000,
  'nbf':
      serverTime.subtract(const Duration(seconds: 30)).millisecondsSinceEpoch ~/
      1000,
  'exp': offlineUntil.millisecondsSinceEpoch ~/ 1000,
  'serverTime': serverTime.toIso8601String(),
  'offlineUntil': offlineUntil.toIso8601String(),
}).withSigningKeyId('k1');

Map<String, dynamic> _manifestJson(List<Map<String, dynamic>> pages) => {
  'version': 1,
  'packageId': 'package-1',
  'userId': 'user-1',
  'chapterId': 'chapter-1',
  'comicId': 'comic-1',
  'deviceKeyId': 'device-key-1',
  'deviceIdHash': 'c' * 64,
  'deviceKeySha256': 'b' * 64,
  'contentRevision': 'revision-1',
  'pageCount': pages.length,
  'offsetBase': 'PAYLOAD',
  'cipher': 'AES-256-GCM',
  'tagLengthBits': 128,
  'aadFormat':
      'CVPK1|packageId|userId|chapterId|deviceKeySha256|contentRevision|pageNumber|pageSha256',
  'pages': pages,
};

Map<String, dynamic> _pageJson({required int page, required int offset}) => {
  'pageNumber': page,
  'offset': offset,
  'length': 24,
  'nonce': _b64(List<int>.filled(12, page)),
  'contentType': 'image/jpeg',
  'plaintextLength': 8,
  'pageSha256': 'a' * 64,
  'ciphertextSha256': 'b' * 64,
};

List<int> _header(int length) => [
  ...ascii.encode('CVPK1'),
  (length >> 24) & 0xff,
  (length >> 16) & 0xff,
  (length >> 8) & 0xff,
  length & 0xff,
];

String _b64(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');

OfflineDownloadEntry _entry({
  required DateTime offlineUntil,
  required String licenseToken,
}) => OfflineDownloadEntry(
  chapterId: 'chapter-1',
  comicId: 'comic-1',
  chapterNumber: '1',
  chapterTitle: 'Chapter 1',
  comicTitle: 'Comic',
  licenseToken: licenseToken,
  wrappedContentKey: _b64(List<int>.filled(384, 1)),
  keyAlgorithm: 'RSA-OAEP-SHA256-MGF1SHA1',
  packageSha256: 'e' * 64,
  deviceKeyId: 'device-key-1',
  deviceKeySha256: 'b' * 64,
  downloadedAt: DateTime.utc(2026, 8, 4),
  offlineUntil: offlineUntil,
  sizeBytes: 1234,
  manifest: CvPackManifest(
    version: 1,
    packageId: 'package-1',
    chapterId: 'chapter-1',
    comicId: 'comic-1',
    userId: 'user-1',
    deviceKeyId: 'device-key-1',
    deviceIdHash: 'c' * 64,
    deviceKeySha256: 'b' * 64,
    contentRevision: 'revision-1',
    offsetBase: 'PAYLOAD',
    cipher: 'AES-256-GCM',
    tagLengthBits: 128,
    aadFormat:
        'CVPK1|packageId|userId|chapterId|deviceKeySha256|contentRevision|pageNumber|pageSha256',
    payloadOffset: 100,
    pages: const [],
  ),
);

class _MemoryStorage implements SessionStorage {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _MemoryDecryptedCache implements OfflineDecryptedPageCache {
  final values = <String, Uint8List>{};

  String _key(String account, String chapter, String package, int page) =>
      '$account:$chapter:$package:$page';

  @override
  Future<void> clearAll() async => values.clear();

  @override
  Future<void> deleteChapter({
    required String accountScope,
    required String chapterId,
  }) async {
    values.removeWhere((key, _) => key.startsWith('$accountScope:$chapterId:'));
  }

  @override
  Future<Uint8List?> read({
    required String accountScope,
    required String chapterId,
    required String packageSha256,
    required int pageNumber,
  }) async => values[_key(accountScope, chapterId, packageSha256, pageNumber)];

  @override
  Future<void> write({
    required String accountScope,
    required String chapterId,
    required String packageSha256,
    required int pageNumber,
    required Uint8List bytes,
  }) async {
    values[_key(accountScope, chapterId, packageSha256, pageNumber)] =
        Uint8List.fromList(bytes);
  }
}

class _StaticVerifier implements OfflineLicenseVerifier {
  const _StaticVerifier(this.claims);
  final Map<String, OfflineLicenseClaims> claims;

  @override
  Future<OfflineLicenseClaims> verify(String compactJws) async =>
      claims[compactJws]!;
}

class _FakePlatformSecurity implements OfflinePlatformSecurity {
  _FakePlatformSecurity({required this.clock});

  OfflinePlatformClock clock;

  @override
  Future<void> deleteIdentity(String accountScope) async {}

  @override
  Future<void> clearTransientKeys() async {}

  @override
  Future<Uint8List> decryptPage({
    required String accountScope,
    required String wrappedContentKey,
    required String keyAlgorithm,
    required Uint8List nonce,
    required Uint8List encryptedPage,
    required Uint8List aad,
  }) async => encryptedPage;

  @override
  Future<OfflinePlatformIdentity> getOrCreateIdentity(
    String accountScope,
  ) async => OfflinePlatformIdentity(
    publicKeyX509Base64: 'key',
    publicKeySha256: 'b' * 64,
  );

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<OfflinePlatformClock> readClock() async => clock;

  @override
  Future<Uint8List> signEnrollmentChallenge({
    required String accountScope,
    required Uint8List challenge,
  }) async => challenge;
}
