import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../models/chapter.dart';
import '../models/offline_download.dart';
import '../models/user_profile.dart';
import 'api_client.dart';
import 'offline_download_store.dart';
import 'offline_download_store_contract.dart';
import 'offline_platform_security.dart';
import 'session_storage.dart';

abstract interface class OfflineLicenseVerifier {
  Future<OfflineLicenseClaims> verify(String compactJws);
}

class Ed25519OfflineLicenseVerifier implements OfflineLicenseVerifier {
  Ed25519OfflineLicenseVerifier({
    String? publicKey,
    String issuer = 'comiverse-api',
    String audience = 'comiverse-android',
    String? signingKeyId,
  }) : _configuredPublicKey =
           publicKey ??
           const String.fromEnvironment(
             'OFFLINE_LICENSE_ED25519_PUBLIC_KEY',
             defaultValue:
                 'MCowBQYDK2VwAyEAZuMBZcxZCILZRAEJOxCMylBxw8rRuyQnRz+LzBJJaS8=',
           ),
       _issuer = issuer,
       _audience = audience,
       _signingKeyId =
           signingKeyId ??
           const String.fromEnvironment(
             'OFFLINE_LICENSE_SIGNING_KEY_ID',
             defaultValue: 'offline-ed25519-v1',
           );

  final String _configuredPublicKey;
  final String _issuer;
  final String _audience;
  final String _signingKeyId;

  bool get isConfigured => _configuredPublicKey.trim().isNotEmpty;

  @override
  Future<OfflineLicenseClaims> verify(String compactJws) async {
    if (!isConfigured) {
      throw const OfflineDownloadException(
        'configuration_required',
        'Offline downloads are not configured in this app build.',
      );
    }
    final parts = compactJws.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      throw const OfflineDownloadException(
        'invalid_license',
        'The offline license is invalid.',
      );
    }
    try {
      final header = jsonDecode(utf8.decode(decodeBase64Url(parts[0])));
      if (header is! Map<String, dynamic> ||
          header['alg'] != 'EdDSA' ||
          header['kid'] != _signingKeyId ||
          (header['typ'] != null && header['typ'] != 'JWT')) {
        throw const FormatException('Unsupported JWS header');
      }
      final keyBytes = _decodePublicKey(_configuredPublicKey);
      final algorithm = Ed25519();
      final verified = await algorithm.verify(
        utf8.encode('${parts[0]}.${parts[1]}'),
        signature: Signature(
          decodeBase64Url(parts[2]),
          publicKey: SimplePublicKey(keyBytes, type: KeyPairType.ed25519),
        ),
      );
      if (!verified) throw const FormatException('Invalid signature');
      final payload = jsonDecode(utf8.decode(decodeBase64Url(parts[1])));
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Invalid payload');
      }
      final claims = OfflineLicenseClaims.fromJson(payload);
      if (claims.issuer != _issuer || claims.audience != _audience) {
        throw const FormatException('Invalid issuer or audience');
      }
      return claims.withSigningKeyId(header['kid']?.toString());
    } catch (_) {
      throw const OfflineDownloadException(
        'invalid_license',
        'The offline license signature could not be verified.',
      );
    }
  }

  List<int> _decodePublicKey(String value) {
    var normalized = value
        .replaceAll(RegExp(r'-----BEGIN[^-]+-----'), '')
        .replaceAll(RegExp(r'-----END[^-]+-----'), '')
        .replaceAll(RegExp(r'\s'), '');
    List<int> bytes;
    try {
      bytes = base64.decode(base64.normalize(normalized));
    } catch (_) {
      bytes = decodeBase64Url(normalized);
    }
    // Ed25519 SubjectPublicKeyInfo is 12-byte DER prefix + 32-byte raw key.
    const ed25519SpkiPrefix = <int>[
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
    if (bytes.length == 44 &&
        listEquals(bytes.sublist(0, 12), ed25519SpkiPrefix)) {
      bytes = bytes.sublist(12);
    }
    if (bytes.length != 32) throw const FormatException('Invalid public key');
    return bytes;
  }
}

class OfflineDownloadService extends ChangeNotifier {
  OfflineDownloadService({
    required this.apiClient,
    OfflineDownloadStore? store,
    OfflinePlatformSecurity? platformSecurity,
    SessionStorage? secureStorage,
    OfflineLicenseVerifier? licenseVerifier,
  }) : store = store ?? const PrivateOfflineDownloadStore(),
       platformSecurity =
           platformSecurity ?? const AndroidOfflinePlatformSecurity(),
       secureStorage = secureStorage ?? const SecureSessionStorage(),
       licenseVerifier = licenseVerifier ?? Ed25519OfflineLicenseVerifier();

  static const maximumPackageBytes = 150 * 1024 * 1024;
  static const maximumPageCiphertextBytes = 12 * 1024 * 1024 + 16;
  static const maximumPages = 200;
  static const renewalWindow = Duration(hours: 24);
  static const rollbackTolerance = Duration(minutes: 2);
  static const maximumOfflinePeriod = Duration(days: 7, minutes: 5);
  static const _deviceIdKey = 'comiverse_offline_install_id_v1';

  final ApiClient apiClient;
  final OfflineDownloadStore store;
  final OfflinePlatformSecurity platformSecurity;
  final SessionStorage secureStorage;
  final OfflineLicenseVerifier licenseVerifier;

  String? _accountScope;
  final Set<String> _verifiedPackageHashes = {};
  final Map<String, Future<OfflineDownloadEntry>> _activeDownloads = {};
  final Map<String, Future<OfflineDownloadEntry>> _activeRenewals = {};
  final Map<String, _OpenOfflineSession> _openSessions = {};
  final Map<String, _TrustedTimeAnchor> _trustedAnchors = {};
  int _decryptionEpoch = 0;
  bool _isForeground = true;

  String? get accountScope => _accountScope;
  int get decryptionEpoch => _decryptionEpoch;
  bool get isForeground => _isForeground;

  bool get isConfigured =>
      licenseVerifier is! Ed25519OfflineLicenseVerifier ||
      (licenseVerifier as Ed25519OfflineLicenseVerifier).isConfigured;

  Future<bool> get isSupported async =>
      isConfigured &&
      await store.isSupported() &&
      await platformSecurity.isSupported();

  Future<void> bindAccount(UserProfile? user) async {
    final next = user?.userId?.trim();
    if (next == _accountScope) return;
    _accountScope = next == null || next.isEmpty ? null : next;
    clearDecryptedMemory();
    notifyListeners();
  }

  void clearDecryptedMemory() {
    _verifiedPackageHashes.clear();
    _openSessions.clear();
    _trustedAnchors.clear();
    _decryptionEpoch++;
    notifyListeners();
  }

  Future<List<OfflineDownloadEntry>> listDownloads() async {
    final account = _requireAccount();
    final ids = await _readIndex(account);
    final entries = <OfflineDownloadEntry>[];
    for (final chapterId in ids) {
      final entry = await _readEntry(account, chapterId);
      if (entry != null &&
          await store.packageExists(
            accountScope: account,
            chapterId: chapterId,
          )) {
        entries.add(entry);
      }
    }
    entries.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return entries;
  }

  Future<bool> hasDownload(String chapterId) async {
    final account = _accountScope;
    if (account == null) return false;
    return await _readEntry(account, chapterId) != null &&
        await store.packageExists(accountScope: account, chapterId: chapterId);
  }

  Future<List<OfflineRegisteredDevice>> listRegisteredDevices() async {
    _requireAccount();
    try {
      return await apiClient.getOfflineDevices();
    } on ApiException catch (error) {
      throw _mapApiException(error);
    }
  }

  Future<String?> currentDeviceKeyId() async {
    final account = _requireAccount();
    final raw = await secureStorage.read(_deviceRegistrationKey(account));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? decoded['deviceKeyId']?.toString()
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> revokeDevice(String deviceKeyId) async {
    final account = _requireAccount();
    try {
      await apiClient.revokeOfflineDevice(deviceKeyId);
    } on ApiException catch (error) {
      throw _mapApiException(error);
    }
    if (deviceKeyId == await currentDeviceKeyId()) {
      await deleteAllDownloads();
      await secureStorage.delete(_deviceRegistrationKey(account));
      await platformSecurity.deleteIdentity(account);
      clearDecryptedMemory();
    }
    notifyListeners();
  }

  Future<OfflineDownloadEntry> downloadChapter({
    required ChapterLite chapter,
    required String comicTitle,
  }) {
    final operationKey = '${_accountHash(_requireAccount())}:${chapter.id}';
    final existing = _activeDownloads[operationKey];
    if (existing != null) return existing;
    final operation = _downloadChapter(
      chapter: chapter,
      comicTitle: comicTitle,
    );
    _activeDownloads[operationKey] = operation;
    operation.whenComplete(() => _activeDownloads.remove(operationKey));
    return operation;
  }

  Future<OfflineDownloadEntry> _downloadChapter({
    required ChapterLite chapter,
    required String comicTitle,
  }) async {
    final account = _requireAccount();
    if (!await isSupported) {
      throw const OfflineDownloadException(
        'unsupported',
        'Secure offline downloads are only available in a configured Android build.',
      );
    }
    final deviceId = await _getOrCreateDeviceId();
    final identity = await platformSecurity.getOrCreateIdentity(account);
    final device = await _ensureDeviceEnrollment(
      account: account,
      deviceId: deviceId,
      identity: identity,
    );
    late final OfflinePackageResponse response;
    try {
      response = await apiClient.downloadOfflineChapter(
        chapterId: chapter.id,
        deviceKeyId: device.deviceKeyId,
      );
    } on ApiException catch (error) {
      // Device not found on server → clear enrollment so next attempt re-enrolls
      if (error.statusCode == 404 || error.statusCode == 403) {
        await secureStorage.delete(_deviceRegistrationKey(account));
      }
      throw _mapApiException(error);
    }

    final claims = await licenseVerifier.verify(response.headers.licenseToken);
    _validateLicenseClaims(
      claims: claims,
      account: account,
      deviceId: deviceId,
      deviceKeyId: device.deviceKeyId,
      identity: identity,
      chapterId: chapter.id,
      header: response.headers,
    );

    StagedOfflinePackage? staged;
    try {
      staged = await store.stagePackage(
        accountScope: account,
        chapterId: chapter.id,
        bytes: response.bytes,
        maximumBytes: maximumPackageBytes,
      );
      if (staged.sha256.toLowerCase() != claims.packageSha256 ||
          staged.sha256.toLowerCase() !=
              response.headers.packageSha256.toLowerCase() ||
          staged.length != claims.packageSize) {
        throw const OfflineDownloadException(
          'corrupted_package',
          'The downloaded chapter failed its integrity check.',
        );
      }
      final manifest = await _readAndValidateManifest(
        account: account,
        chapterId: chapter.id,
        packageLength: staged.length,
        claims: claims,
        staged: true,
      );
      final entry = OfflineDownloadEntry(
        chapterId: chapter.id,
        comicId: claims.comicId,
        chapterNumber: chapter.chapterNumber,
        chapterTitle: chapter.title,
        comicTitle: comicTitle,
        licenseToken: response.headers.licenseToken,
        wrappedContentKey: response.headers.wrappedContentKey,
        keyAlgorithm: response.headers.keyAlgorithm,
        packageSha256: claims.packageSha256,
        deviceKeyId: device.deviceKeyId,
        deviceKeySha256: identity.publicKeySha256,
        downloadedAt: response.headers.serverTime,
        offlineUntil: claims.offlineUntil,
        sizeBytes: staged.length,
        manifest: manifest,
      );
      await store.commitPackage(staged);
      staged = null;
      await _writeEntry(account, entry);
      await _anchorTrustedTime(account, claims.serverTime);
      _verifiedPackageHashes.add(_verifiedKey(entry));
      _openSessions.remove(entry.chapterId);
      notifyListeners();
      return entry;
    } finally {
      if (staged != null) await store.discardStagedPackage(staged);
    }
  }

  Future<OfflineDownloadEntry> renewChapter(String chapterId) async {
    final operationKey = '${_accountHash(_requireAccount())}:$chapterId';
    final active = _activeRenewals[operationKey];
    if (active != null) return active;
    final operation = _renewChapter(chapterId);
    _activeRenewals[operationKey] = operation;
    operation.whenComplete(() => _activeRenewals.remove(operationKey));
    return operation;
  }

  Future<OfflineDownloadEntry> _renewChapter(String chapterId) async {
    final account = _requireAccount();
    final existing = await _readEntry(account, chapterId);
    if (existing == null) {
      throw const OfflineDownloadException(
        'not_downloaded',
        'This chapter is not downloaded.',
      );
    }
    final previous = await licenseVerifier.verify(existing.licenseToken);
    late final OfflineLicenseRenewal renewal;
    try {
      renewal = await apiClient.renewOfflineLicense(
        packageId: previous.packageId,
        deviceKeyId: existing.deviceKeyId,
      );
    } on ApiException catch (error) {
      throw _mapApiException(error);
    }
    final claims = await licenseVerifier.verify(renewal.licenseToken);
    final deviceId = await _getOrCreateDeviceId();
    final identity = await platformSecurity.getOrCreateIdentity(account);
    _validateLicenseClaims(
      claims: claims,
      account: account,
      deviceId: deviceId,
      deviceKeyId: existing.deviceKeyId,
      identity: identity,
      chapterId: existing.chapterId,
      header: OfflinePackageHeaders(
        licenseToken: renewal.licenseToken,
        wrappedContentKey: renewal.wrappedContentKey,
        keyAlgorithm: renewal.keyAlgorithm,
        expiresAt: claims.expiresAt,
        serverTime: renewal.serverTime,
        packageSha256: renewal.packageSha256,
        manifestSha256: claims.manifestSha256,
        packageId: renewal.packageId,
        deviceKeyId: renewal.deviceKeyId,
        formatVersion: renewal.formatVersion,
        signingKeyId: renewal.signingKeyId,
      ),
    );
    if (claims.packageId != previous.packageId ||
        claims.packageSha256 != previous.packageSha256 ||
        claims.manifestSha256 != previous.manifestSha256 ||
        claims.contentRevision != previous.contentRevision ||
        claims.packageSize != previous.packageSize ||
        renewal.packageSize != existing.sizeBytes) {
      throw const OfflineDownloadException(
        'redownload_required',
        'This chapter changed and must be downloaded again.',
      );
    }
    final updated = existing.copyWith(
      licenseToken: renewal.licenseToken,
      wrappedContentKey: renewal.wrappedContentKey,
      keyAlgorithm: renewal.keyAlgorithm,
      offlineUntil: claims.offlineUntil,
    );
    await _writeEntry(account, updated);
    await _anchorTrustedTime(account, claims.serverTime);
    notifyListeners();
    _openSessions.remove(chapterId);
    return updated;
  }

  Future<ChapterDetail> openChapter(String chapterId) async {
    var entry = await _validatedEntry(chapterId);
    late DateTime estimatedNow;
    try {
      estimatedNow = await _validateTrustedTime(entry);
    } on OfflineDownloadException catch (error) {
      if (!error.requiresOnline) rethrow;
      entry = await renewChapter(chapterId);
      estimatedNow = await _validateTrustedTime(entry);
    }
    if (entry.offlineUntil.difference(estimatedNow) <= renewalWindow) {
      unawaited(renewChapter(chapterId).catchError((_) => entry));
    }
    final claims = await licenseVerifier.verify(entry.licenseToken);
    _openSessions[chapterId] = _OpenOfflineSession(entry, claims);
    return ChapterDetail(
      id: entry.chapterId,
      title: entry.chapterTitle,
      chapterNumber: entry.chapterNumber,
      comicId: entry.comicId,
      images: [
        for (final page in entry.manifest.pages)
          'comiverse-offline://${entry.chapterId}/${page.pageNumber}',
      ],
    );
  }

  Future<Uint8List> readPage(String offlineUri) async {
    if (!_isForeground) {
      throw const OfflineDownloadException(
        'app_backgrounded',
        'Offline pages are locked while the app is in the background.',
      );
    }
    final uri = Uri.tryParse(offlineUri);
    if (uri == null || uri.scheme != 'comiverse-offline') {
      throw const OfflineDownloadException(
        'invalid_page',
        'The offline page reference is invalid.',
      );
    }
    final chapterId = uri.host;
    final pageNumber = int.tryParse(
      uri.pathSegments.isEmpty ? '' : uri.pathSegments.first,
    );
    if (chapterId.isEmpty || pageNumber == null) {
      throw const OfflineDownloadException(
        'invalid_page',
        'The offline page reference is invalid.',
      );
    }
    var session = _openSessions[chapterId];
    if (session == null) {
      final entry = await _validatedEntry(chapterId);
      final claims = await licenseVerifier.verify(entry.licenseToken);
      await _validateTrustedTime(entry);
      session = _OpenOfflineSession(entry, claims);
      _openSessions[chapterId] = session;
    } else {
      await _validateTrustedTime(session.entry);
    }
    final entry = session.entry;
    final claims = session.claims;
    final page = entry.manifest.page(pageNumber);
    final encrypted = await store.readRange(
      accountScope: _requireAccount(),
      chapterId: entry.chapterId,
      offset: entry.manifest.payloadOffset + page.offset,
      length: page.length,
    );
    try {
      if (sha256.convert(encrypted).toString() != page.ciphertextSha256) {
        throw const OfflineDownloadException(
          'corrupted_package',
          'The downloaded page failed its integrity check.',
        );
      }
      final plaintext = await platformSecurity.decryptPage(
        accountScope: _requireAccount(),
        wrappedContentKey: entry.wrappedContentKey,
        keyAlgorithm: entry.keyAlgorithm,
        nonce: Uint8List.fromList(decodeBase64Url(page.nonce)),
        encryptedPage: encrypted,
        aad: Uint8List.fromList(
          utf8.encode(claims.aadForPage(pageNumber, page.pageSha256)),
        ),
      );
      if (plaintext.length != page.plaintextLength ||
          sha256.convert(plaintext).toString() != page.pageSha256) {
        plaintext.fillRange(0, plaintext.length, 0);
        throw const OfflineDownloadException(
          'corrupted_package',
          'The decrypted page failed its integrity check.',
        );
      }
      return plaintext;
    } on OfflineDownloadException {
      rethrow;
    } catch (_) {
      throw const OfflineDownloadException(
        'decryption_failed',
        'This download cannot be opened on this device. Download it again.',
      );
    } finally {
      encrypted.fillRange(0, encrypted.length, 0);
    }
  }

  void releasePageBytes(Uint8List bytes) {
    bytes.fillRange(0, bytes.length, 0);
  }

  Future<void> deleteDownload(String chapterId) async {
    final account = _requireAccount();
    await store.deletePackage(accountScope: account, chapterId: chapterId);
    await secureStorage.delete(_entryKey(account, chapterId));
    final ids = await _readIndex(account)
      ..remove(chapterId);
    await _writeIndex(account, ids);
    _verifiedPackageHashes.removeWhere((key) => key.startsWith('$chapterId:'));
    _openSessions.remove(chapterId);
    notifyListeners();
  }

  Future<void> deleteAllDownloads() async {
    final account = _requireAccount();
    final ids = await _readIndex(account);
    await store.deleteAccountPackages(account);
    await Future.wait([
      for (final id in ids) secureStorage.delete(_entryKey(account, id)),
      secureStorage.delete(_indexKey(account)),
      secureStorage.delete(_clockKey(account)),
    ]);
    clearDecryptedMemory();
    notifyListeners();
  }

  Future<void> onAppBackgrounded() async {
    _isForeground = false;
    clearDecryptedMemory();
  }

  void onAppResumed() {
    if (_isForeground) return;
    _isForeground = true;
    notifyListeners();
  }

  @visibleForTesting
  Future<void> anchorTrustedTimeForTesting(DateTime serverTime) =>
      _anchorTrustedTime(_requireAccount(), serverTime);

  @visibleForTesting
  Future<DateTime> validateTrustedTimeForTesting(OfflineDownloadEntry entry) =>
      _validateTrustedTime(entry);

  @visibleForTesting
  Future<void> writeEntryForTesting(OfflineDownloadEntry entry) =>
      _writeEntry(_requireAccount(), entry);

  Future<_RegisteredDevice> _ensureDeviceEnrollment({
    required String account,
    required String deviceId,
    required OfflinePlatformIdentity identity,
  }) async {
    final saved = await secureStorage.read(_deviceRegistrationKey(account));
    if (saved != null) {
      try {
        final json = jsonDecode(saved);
        if (json is Map<String, dynamic> &&
            json['publicKeySha256']?.toString().toLowerCase() ==
                identity.publicKeySha256) {
          final id = json['deviceKeyId']?.toString() ?? '';
          if (id.isNotEmpty) {
            return _RegisteredDevice(
              deviceKeyId: id,
              publicKeySha256: identity.publicKeySha256,
            );
          }
        } else {
          // Key changed (app reinstalled / keystore cleared) – clear stale record
          // so we always re-enroll with the current key.
          await secureStorage.delete(_deviceRegistrationKey(account));
        }
      } catch (_) {
        await secureStorage.delete(_deviceRegistrationKey(account));
      }
    }

    try {
      final challenge = await apiClient.createOfflineDeviceChallenge(
        deviceId: deviceId,
        deviceName: identity.deviceName,
        devicePublicKey: identity.publicKeyX509Base64,
      );
      final now = DateTime.now().toUtc();
      if (challenge.expiresAt.isBefore(
        now.subtract(const Duration(minutes: 2)),
      )) {
        throw const OfflineDownloadException(
          'device_enrollment_failed',
          'The device enrollment challenge expired.',
        );
      }
      final signature = await platformSecurity.signEnrollmentChallenge(
        accountScope: account,
        challenge: Uint8List.fromList(decodeBase64Url(challenge.challenge)),
      );
      final enrollment = await apiClient.enrollOfflineDevice(
        challengeId: challenge.challengeId,
        signature: base64UrlEncode(signature).replaceAll('=', ''),
      );
      if (enrollment.publicKeySha256.isNotEmpty &&
          enrollment.publicKeySha256 != identity.publicKeySha256) {
        throw const OfflineDownloadException(
          'device_enrollment_failed',
          'The server registered a different device key.',
        );
      }
      await secureStorage.write(
        _deviceRegistrationKey(account),
        jsonEncode({
          'deviceKeyId': enrollment.deviceKeyId,
          'publicKeySha256': identity.publicKeySha256,
        }),
      );
      return _RegisteredDevice(
        deviceKeyId: enrollment.deviceKeyId,
        publicKeySha256: identity.publicKeySha256,
      );
    } on ApiException catch (error) {
      throw _mapApiException(error);
    }
  }

  void _validateLicenseClaims({
    required OfflineLicenseClaims claims,
    required String account,
    required String deviceId,
    required String deviceKeyId,
    required OfflinePlatformIdentity identity,
    required String chapterId,
    required OfflinePackageHeaders header,
  }) {
    void fail(String detail) => throw OfflineDownloadException(
      'invalid_license',
      'License mismatch: $detail',
    );

    if (claims.formatVersion != 1) fail('formatVersion');
    if (claims.userId != account) fail('userId');
    if (claims.chapterId != chapterId) fail('chapterId');
    final expectedDeviceIdHash =
        sha256.convert(utf8.encode(deviceId)).toString();
    if (claims.deviceIdHash != expectedDeviceIdHash) fail('deviceIdHash');
    if (claims.deviceKeyId != deviceKeyId) fail('deviceKeyId');
    if (claims.deviceKeySha256 != identity.publicKeySha256) {
      fail(
        'deviceKeySha256: claims=${claims.deviceKeySha256} vs local=${identity.publicKeySha256}',
      );
    }
    if (claims.packageId != header.packageId) fail('packageId');
    if (claims.deviceKeyId != header.deviceKeyId) fail('header.deviceKeyId');
    if (claims.packageSha256 != header.packageSha256.toLowerCase()) {
      fail('packageSha256');
    }
    if (claims.manifestSha256 != header.manifestSha256.toLowerCase()) {
      fail('manifestSha256');
    }
    if (claims.keyAlgorithm != header.keyAlgorithm) fail('keyAlgorithm');
    if (claims.formatVersion != header.formatVersion) {
      fail('header.formatVersion');
    }
    if (claims.signingKeyId != header.signingKeyId) fail('signingKeyId');
    final computedWrappedKeySha256 =
        sha256.convert(decodeBase64Url(header.wrappedContentKey)).toString();
    if (claims.wrappedKeySha256 != computedWrappedKeySha256) {
      fail(
        'wrappedKeySha256: claims=${claims.wrappedKeySha256} vs computed=$computedWrappedKeySha256',
      );
    }
    if (claims.expiresAt.difference(header.expiresAt).abs() >
        const Duration(seconds: 2)) {
      fail('expiresAt');
    }
    if (claims.notBefore.isAfter(
      claims.serverTime.add(const Duration(seconds: 30)),
    )) {
      fail('notBefore');
    }
    if (claims.issuedAt.difference(claims.serverTime).abs() >
        const Duration(minutes: 1)) {
      fail('issuedAt vs serverTime clock drift');
    }
    if (claims.offlineUntil.isAfter(
      claims.expiresAt.add(const Duration(seconds: 2)),
    )) {
      fail('offlineUntil > expiresAt');
    }
    if (claims.offlineUntil.difference(claims.issuedAt) > maximumOfflinePeriod) {
      fail('offlineUntil period too long');
    }
    if (header.serverTime.difference(claims.serverTime).abs() >
        const Duration(minutes: 1)) {
      fail('header.serverTime vs claims.serverTime');
    }
  }

  Future<CvPackManifest> _readAndValidateManifest({
    required String account,
    required String chapterId,
    required int packageLength,
    required OfflineLicenseClaims claims,
    required bool staged,
  }) async {
    if (packageLength <= CvPackManifest.fixedHeaderLength ||
        packageLength > maximumPackageBytes) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter has an invalid size.',
      );
    }
    final header = await store.readRange(
      accountScope: account,
      chapterId: chapterId,
      offset: 0,
      length: CvPackManifest.fixedHeaderLength,
      staged: staged,
    );
    final manifestLength =
        (header[5] << 24) | (header[6] << 16) | (header[7] << 8) | header[8];
    if (manifestLength <= 0 ||
        manifestLength > CvPackManifest.maximumManifestBytes) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter manifest is invalid.',
      );
    }
    final manifestBytes = await store.readRange(
      accountScope: account,
      chapterId: chapterId,
      offset: CvPackManifest.fixedHeaderLength,
      length: manifestLength,
      staged: staged,
    );
    if (sha256.convert(manifestBytes).toString() != claims.manifestSha256) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter manifest failed its integrity check.',
      );
    }
    final manifest = CvPackManifest.parse(
      header: header,
      manifestBytes: manifestBytes,
      packageLength: packageLength,
    );
    if (manifest.version != 1 ||
        manifest.pages.length > maximumPages ||
        manifest.packageId != claims.packageId ||
        manifest.userId != claims.userId ||
        manifest.chapterId != claims.chapterId ||
        manifest.comicId != claims.comicId ||
        manifest.deviceKeyId != claims.deviceKeyId ||
        manifest.deviceIdHash != claims.deviceIdHash ||
        manifest.deviceKeySha256 != claims.deviceKeySha256 ||
        manifest.offsetBase != 'PAYLOAD' ||
        manifest.cipher != 'AES-256-GCM' ||
        manifest.tagLengthBits != 128 ||
        manifest.aadFormat !=
            'CVPK1|packageId|userId|chapterId|deviceKeySha256|contentRevision|pageNumber|pageSha256' ||
        manifest.contentRevision != claims.contentRevision) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter manifest does not match its license.',
      );
    }
    final allowedTypes = {'image/jpeg', 'image/png', 'image/webp'};
    final numbers = manifest.pages.map((page) => page.pageNumber).toList()
      ..sort();
    for (var index = 0; index < manifest.pages.length; index++) {
      final page = manifest.pages[index];
      if (numbers[index] != index + 1 ||
          page.length > maximumPageCiphertextBytes ||
          page.plaintextLength > maximumPageCiphertextBytes - 16 ||
          !allowedTypes.contains(page.contentType.toLowerCase())) {
        throw const OfflineDownloadException(
          'corrupted_package',
          'The downloaded chapter contains an invalid page.',
        );
      }
    }
    return manifest;
  }

  Future<OfflineDownloadEntry> _validatedEntry(String chapterId) async {
    final account = _requireAccount();
    final entry = await _readEntry(account, chapterId);
    if (entry == null ||
        !await store.packageExists(
          accountScope: account,
          chapterId: chapterId,
        )) {
      throw const OfflineDownloadException(
        'not_downloaded',
        'This chapter is not downloaded.',
      );
    }
    final claims = await licenseVerifier.verify(entry.licenseToken);
    final deviceId = await _getOrCreateDeviceId();
    final identity = await platformSecurity.getOrCreateIdentity(account);
    _validateLicenseClaims(
      claims: claims,
      account: account,
      deviceId: deviceId,
      deviceKeyId: entry.deviceKeyId,
      identity: identity,
      chapterId: chapterId,
      header: OfflinePackageHeaders(
        licenseToken: entry.licenseToken,
        wrappedContentKey: entry.wrappedContentKey,
        keyAlgorithm: entry.keyAlgorithm,
        expiresAt: claims.expiresAt,
        serverTime: claims.issuedAt,
        packageSha256: entry.packageSha256,
        manifestSha256: claims.manifestSha256,
        packageId: claims.packageId,
        deviceKeyId: entry.deviceKeyId,
        formatVersion: claims.formatVersion,
        signingKeyId: claims.signingKeyId ?? '',
      ),
    );
    final verifiedKey = _verifiedKey(entry);
    if (!_verifiedPackageHashes.contains(verifiedKey)) {
      final actualHash = await store.packageSha256(
        accountScope: account,
        chapterId: chapterId,
      );
      if (actualHash.toLowerCase() != claims.packageSha256) {
        throw const OfflineDownloadException(
          'corrupted_package',
          'The downloaded chapter failed its integrity check.',
        );
      }
      _verifiedPackageHashes.add(verifiedKey);
    }
    // Always reparse the small on-disk manifest. Secure-storage metadata is
    // only an index and must never be allowed to choose ciphertext offsets.
    final length = await store.packageLength(
      accountScope: account,
      chapterId: chapterId,
    );
    if (length != claims.packageSize) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter size does not match its license.',
      );
    }
    final actualManifest = await _readAndValidateManifest(
      account: account,
      chapterId: chapterId,
      packageLength: length,
      claims: claims,
      staged: false,
    );
    return entry.copyWith(manifest: actualManifest, sizeBytes: length);
  }

  Future<void> _anchorTrustedTime(String account, DateTime serverTime) async {
    final clock = await platformSecurity.readClock();
    final anchor = _TrustedTimeAnchor(
      serverEpochMs: serverTime.millisecondsSinceEpoch,
      elapsedRealtimeMs: clock.elapsedRealtimeMillis,
      bootCount: clock.bootCount,
      lastWallEpochMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      lastElapsedRealtimeMs: clock.elapsedRealtimeMillis,
      lastPersistedElapsedMs: clock.elapsedRealtimeMillis,
    );
    _trustedAnchors[account] = anchor;
    await secureStorage.write(_clockKey(account), jsonEncode(anchor.toJson()));
  }

  Future<DateTime> _validateTrustedTime(OfflineDownloadEntry entry) async {
    final account = _requireAccount();
    try {
      var anchor = _trustedAnchors[account];
      if (anchor == null) {
        final raw = await secureStorage.read(_clockKey(account));
        if (raw == null) throw const FormatException();
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        anchor = _TrustedTimeAnchor.fromJson(decoded);
        _trustedAnchors[account] = anchor;
      }
      final clock = await platformSecurity.readClock();
      final wallNow = DateTime.now().toUtc().millisecondsSinceEpoch;
      if (clock.bootCount < 0 ||
          anchor.bootCount != clock.bootCount ||
          clock.elapsedRealtimeMillis < anchor.elapsedRealtimeMs ||
          clock.elapsedRealtimeMillis < anchor.lastElapsedRealtimeMs ||
          wallNow + rollbackTolerance.inMilliseconds < anchor.lastWallEpochMs) {
        throw const OfflineDownloadException(
          'online_required',
          'The device clock changed or the device restarted. Connect to the Internet to verify access.',
        );
      }
      final estimated = DateTime.fromMillisecondsSinceEpoch(
        anchor.serverEpochMs +
            (clock.elapsedRealtimeMillis - anchor.elapsedRealtimeMs),
        isUtc: true,
      );
      final claims = await licenseVerifier.verify(entry.licenseToken);
      if (entry.offlineUntil != claims.offlineUntil ||
          !estimated.isBefore(claims.offlineUntil)) {
        throw const OfflineDownloadException(
          'online_required',
          'This offline license expired. Connect to the Internet to renew it.',
        );
      }
      anchor.lastWallEpochMs = max(anchor.lastWallEpochMs, wallNow);
      anchor.lastElapsedRealtimeMs = clock.elapsedRealtimeMillis;
      if (clock.elapsedRealtimeMillis - anchor.lastPersistedElapsedMs >=
          const Duration(minutes: 1).inMilliseconds) {
        anchor.lastPersistedElapsedMs = clock.elapsedRealtimeMillis;
        await secureStorage.write(
          _clockKey(account),
          jsonEncode(anchor.toJson()),
        );
      }
      return estimated;
    } on OfflineDownloadException {
      rethrow;
    } catch (_) {
      throw const OfflineDownloadException(
        'online_required',
        'Connect to the Internet to verify your offline access.',
      );
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final saved = await secureStorage.read(_deviceIdKey);
    if (saved != null && saved.trim().length >= 20) return saved.trim();
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final value = base64UrlEncode(bytes).replaceAll('=', '');
    await secureStorage.write(_deviceIdKey, value);
    return value;
  }

  Future<List<String>> _readIndex(String account) async {
    final raw = await secureStorage.read(_indexKey(account));
    if (raw == null) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
      }
    } catch (_) {}
    return <String>[];
  }

  Future<void> _writeIndex(String account, List<String> ids) =>
      secureStorage.write(_indexKey(account), jsonEncode(ids.toSet().toList()));

  Future<OfflineDownloadEntry?> _readEntry(
    String account,
    String chapterId,
  ) async {
    final raw = await secureStorage.read(_entryKey(account, chapterId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return OfflineDownloadEntry.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeEntry(String account, OfflineDownloadEntry entry) async {
    await secureStorage.write(
      _entryKey(account, entry.chapterId),
      jsonEncode(entry.toJson()),
    );
    final ids = await _readIndex(account);
    if (!ids.contains(entry.chapterId)) ids.add(entry.chapterId);
    await _writeIndex(account, ids);
  }

  OfflineDownloadException _mapApiException(ApiException error) {
    debugPrint(
      'MAP_API_EXCEPTION: statusCode=${error.statusCode}, code=${error.code}, message=${error.message}',
    );
    final code = error.code?.toUpperCase();
    if (error.statusCode == 403 && code != 'PREMIUM_REQUIRED') {
      return OfflineDownloadException(
        code == 'OFFLINE_DEVICE_REVOKED' ||
                code == 'OFFLINE_PACKAGE_DEVICE_MISMATCH'
            ? 'device_changed'
            : 'access_denied',
        error.message,
      );
    }
    if (error.statusCode == 409 && code == 'OFFLINE_PACKAGE_OUTDATED') {
      return OfflineDownloadException(
        'redownload_required',
        error.message,
      );
    }
    return switch (error.statusCode) {
      401 => OfflineDownloadException(
        'authentication_required',
        error.message,
      ),
      403 => OfflineDownloadException(
        'premium_required',
        error.message,
      ),
      404 => OfflineDownloadException(
        'not_found',
        error.message,
      ),
      413 => OfflineDownloadException(
        'too_large',
        error.message,
      ),
      429 => OfflineDownloadException(
        'rate_limited',
        error.message,
      ),
      _ => OfflineDownloadException('network_error', error.message),
    };
  }

  String _requireAccount() {
    final account = _accountScope;
    if (account == null || account.isEmpty) {
      throw const OfflineDownloadException(
        'authentication_required',
        'Sign in before using offline downloads.',
      );
    }
    return account;
  }

  String _accountHash(String account) =>
      sha256.convert(utf8.encode(account)).toString();

  String _indexKey(String account) =>
      'comiverse_offline_index_v1_${_accountHash(account)}';

  String _entryKey(String account, String chapterId) =>
      'comiverse_offline_entry_v1_${_accountHash(account)}_'
      '${sha256.convert(utf8.encode(chapterId))}';

  String _clockKey(String account) =>
      'comiverse_offline_clock_v1_${_accountHash(account)}';

  String _deviceRegistrationKey(String account) =>
      'comiverse_offline_device_v1_${_accountHash(account)}';

  String _verifiedKey(OfflineDownloadEntry entry) =>
      '${entry.chapterId}:${entry.packageSha256}';
}

class _RegisteredDevice {
  const _RegisteredDevice({
    required this.deviceKeyId,
    required this.publicKeySha256,
  });

  final String deviceKeyId;
  final String publicKeySha256;
}

class _OpenOfflineSession {
  const _OpenOfflineSession(this.entry, this.claims);

  final OfflineDownloadEntry entry;
  final OfflineLicenseClaims claims;
}

class _TrustedTimeAnchor {
  _TrustedTimeAnchor({
    required this.serverEpochMs,
    required this.elapsedRealtimeMs,
    required this.bootCount,
    required this.lastWallEpochMs,
    required this.lastElapsedRealtimeMs,
    required this.lastPersistedElapsedMs,
  });

  final int serverEpochMs;
  final int elapsedRealtimeMs;
  final int bootCount;
  int lastWallEpochMs;
  int lastElapsedRealtimeMs;
  int lastPersistedElapsedMs;

  factory _TrustedTimeAnchor.fromJson(Map<String, dynamic> json) {
    int value(String key) => (json[key] as num).toInt();
    return _TrustedTimeAnchor(
      serverEpochMs: value('serverEpochMs'),
      elapsedRealtimeMs: value('elapsedRealtimeMs'),
      bootCount: value('bootCount'),
      lastWallEpochMs: value('lastWallEpochMs'),
      lastElapsedRealtimeMs: value('lastElapsedRealtimeMs'),
      lastPersistedElapsedMs:
          (json['lastPersistedElapsedMs'] as num?)?.toInt() ??
          value('lastElapsedRealtimeMs'),
    );
  }

  Map<String, int> toJson() => {
    'serverEpochMs': serverEpochMs,
    'elapsedRealtimeMs': elapsedRealtimeMs,
    'bootCount': bootCount,
    'lastWallEpochMs': lastWallEpochMs,
    'lastElapsedRealtimeMs': lastElapsedRealtimeMs,
    'lastPersistedElapsedMs': lastPersistedElapsedMs,
  };
}
