import 'dart:convert';

enum OfflineDownloadAccess {
  available,
  renewalRequired,
  wrongAccount,
  deviceChanged,
  corrupted,
}

class OfflineDownloadException implements Exception {
  const OfflineDownloadException(this.code, this.message);

  final String code;
  final String message;

  bool get requiresPremium => code == 'premium_required';
  bool get requiresOnline => code == 'online_required';

  @override
  String toString() => message;
}

class OfflineDeviceChallenge {
  const OfflineDeviceChallenge({
    required this.challengeId,
    required this.challenge,
    required this.expiresAt,
    required this.serverTime,
  });

  final String challengeId;
  final String challenge;
  final DateTime expiresAt;
  final DateTime serverTime;

  factory OfflineDeviceChallenge.fromJson(Map<String, dynamic> json) {
    final source = _unwrapMap(json);
    return OfflineDeviceChallenge(
      challengeId: _requiredText(source, 'challengeId'),
      challenge: _requiredText(source, 'challenge'),
      expiresAt: _requiredDate(source, 'expiresAt'),
      serverTime: _requiredDate(source, 'serverTime'),
    );
  }
}

class OfflineDeviceEnrollment {
  const OfflineDeviceEnrollment({
    required this.deviceKeyId,
    required this.publicKeySha256,
    this.serverTime,
  });

  final String deviceKeyId;
  final String publicKeySha256;
  final DateTime? serverTime;

  factory OfflineDeviceEnrollment.fromJson(Map<String, dynamic> json) {
    final source = _unwrapMap(json);
    return OfflineDeviceEnrollment(
      deviceKeyId: _requiredText(source, 'deviceKeyId'),
      publicKeySha256:
          (source['publicKeySha256'] ?? source['fingerprint'] ?? '')
              .toString()
              .toLowerCase(),
      serverTime: DateTime.tryParse(
        (source['serverTime'] ?? '').toString(),
      )?.toUtc(),
    );
  }
}

class OfflineRegisteredDevice {
  const OfflineRegisteredDevice({
    required this.deviceKeyId,
    required this.deviceName,
    required this.publicKeySha256,
    required this.revoked,
    this.enrolledAt,
    this.lastSeenAt,
  });

  final String deviceKeyId;
  final String deviceName;
  final String publicKeySha256;
  final bool revoked;
  final DateTime? enrolledAt;
  final DateTime? lastSeenAt;

  factory OfflineRegisteredDevice.fromJson(Map<String, dynamic> json) =>
      OfflineRegisteredDevice(
        deviceKeyId: _requiredText(json, 'deviceKeyId'),
        deviceName: (json['deviceName'] ?? 'Mobile device').toString(),
        publicKeySha256: _requiredText(json, 'publicKeySha256').toLowerCase(),
        revoked: json['revoked'] == true,
        enrolledAt: DateTime.tryParse(
          (json['enrolledAt'] ?? '').toString(),
        )?.toUtc(),
        lastSeenAt: DateTime.tryParse(
          (json['lastSeenAt'] ?? '').toString(),
        )?.toUtc(),
      );
}

class OfflinePackageHeaders {
  const OfflinePackageHeaders({
    required this.licenseToken,
    required this.wrappedContentKey,
    required this.keyAlgorithm,
    required this.expiresAt,
    required this.serverTime,
    required this.packageSha256,
    required this.manifestSha256,
    required this.packageId,
    required this.deviceKeyId,
    required this.formatVersion,
    required this.signingKeyId,
  });

  final String licenseToken;
  final String wrappedContentKey;
  final String keyAlgorithm;
  final DateTime expiresAt;
  final DateTime serverTime;
  final String packageSha256;
  final String manifestSha256;
  final String packageId;
  final String deviceKeyId;
  final int formatVersion;
  final String signingKeyId;
}

class OfflineLicenseClaims {
  const OfflineLicenseClaims({
    required this.issuer,
    required this.audience,
    required this.licenseId,
    required this.userId,
    required this.chapterId,
    required this.comicId,
    required this.deviceIdHash,
    required this.deviceKeyId,
    required this.deviceKeySha256,
    required this.packageId,
    required this.contentRevision,
    required this.packageSha256,
    required this.manifestSha256,
    required this.packageSize,
    required this.wrappedKeySha256,
    required this.keyAlgorithm,
    required this.issuedAt,
    required this.notBefore,
    required this.expiresAt,
    required this.serverTime,
    required this.offlineUntil,
    required this.formatVersion,
    this.signingKeyId,
  });

  final String issuer;
  final String audience;
  final String licenseId;
  final String userId;
  final String chapterId;
  final String comicId;
  final String deviceIdHash;
  final String deviceKeyId;
  final String deviceKeySha256;
  final String packageId;
  final String contentRevision;
  final String packageSha256;
  final String manifestSha256;
  final int packageSize;
  final String wrappedKeySha256;
  final String keyAlgorithm;
  final DateTime issuedAt;
  final DateTime notBefore;
  final DateTime expiresAt;
  final DateTime serverTime;
  final DateTime offlineUntil;
  final int formatVersion;
  final String? signingKeyId;

  factory OfflineLicenseClaims.fromJson(Map<String, dynamic> json) {
    return OfflineLicenseClaims(
      issuer: _requiredText(json, 'iss'),
      audience: _audience(json['aud']),
      licenseId: _requiredText(json, 'jti'),
      userId: (json['userId'] ?? json['sub'] ?? '').toString(),
      chapterId: _requiredText(json, 'chapterId'),
      comicId: _requiredText(json, 'comicId'),
      deviceIdHash: _requiredText(json, 'deviceIdHash').toLowerCase(),
      deviceKeyId: _requiredText(json, 'deviceKeyId'),
      deviceKeySha256: _requiredText(json, 'deviceKeySha256').toLowerCase(),
      packageId: _requiredText(json, 'packageId'),
      contentRevision: _requiredText(json, 'contentRevision'),
      packageSha256: _requiredText(json, 'packageSha256').toLowerCase(),
      manifestSha256: _requiredText(json, 'manifestSha256').toLowerCase(),
      packageSize: _requiredInt(json, 'packageSize'),
      wrappedKeySha256: _requiredText(json, 'wrappedKeySha256').toLowerCase(),
      keyAlgorithm: _requiredText(json, 'keyAlgorithm'),
      issuedAt: _epochDate(json['iat'], 'iat'),
      notBefore: _epochDate(json['nbf'], 'nbf'),
      expiresAt: _epochDate(json['exp'], 'exp'),
      serverTime: _requiredDate(json, 'serverTime'),
      offlineUntil: _dateOrEpoch(json['offlineUntil'], 'offlineUntil'),
      formatVersion: _requiredInt(json, 'formatVersion'),
    );
  }

  OfflineLicenseClaims withSigningKeyId(String? value) => OfflineLicenseClaims(
    issuer: issuer,
    audience: audience,
    licenseId: licenseId,
    userId: userId,
    chapterId: chapterId,
    comicId: comicId,
    deviceIdHash: deviceIdHash,
    deviceKeyId: deviceKeyId,
    deviceKeySha256: deviceKeySha256,
    packageId: packageId,
    contentRevision: contentRevision,
    packageSha256: packageSha256,
    manifestSha256: manifestSha256,
    packageSize: packageSize,
    wrappedKeySha256: wrappedKeySha256,
    keyAlgorithm: keyAlgorithm,
    issuedAt: issuedAt,
    notBefore: notBefore,
    expiresAt: expiresAt,
    serverTime: serverTime,
    offlineUntil: offlineUntil,
    formatVersion: formatVersion,
    signingKeyId: value,
  );

  String aadForPage(int pageNumber, String pageSha256) =>
      'CVPK1|$packageId|$userId|$chapterId|$deviceKeySha256|'
      '$contentRevision|$pageNumber|${pageSha256.toLowerCase()}';

  String aadForTranslation(String languageCode, String translationSha256) =>
      'CVPK2|$packageId|$userId|$chapterId|$deviceKeySha256|'
      '$contentRevision|translation|${languageCode.toLowerCase()}|'
      '${translationSha256.toLowerCase()}';
}

class OfflineLicenseRenewal {
  const OfflineLicenseRenewal({
    required this.packageId,
    required this.chapterId,
    required this.comicId,
    required this.deviceKeyId,
    required this.licenseToken,
    required this.wrappedContentKey,
    required this.keyAlgorithm,
    required this.signingKeyId,
    required this.packageSha256,
    required this.packageSize,
    required this.formatVersion,
    required this.offlineUntil,
    required this.serverTime,
  });

  final String packageId;
  final String chapterId;
  final String comicId;
  final String deviceKeyId;
  final String licenseToken;
  final String wrappedContentKey;
  final String keyAlgorithm;
  final String signingKeyId;
  final String packageSha256;
  final int packageSize;
  final int formatVersion;
  final DateTime offlineUntil;
  final DateTime serverTime;

  factory OfflineLicenseRenewal.fromJson(Map<String, dynamic> json) {
    final source = _unwrapMap(json);
    return OfflineLicenseRenewal(
      packageId: _requiredText(source, 'packageId'),
      chapterId: _requiredText(source, 'chapterId'),
      comicId: _requiredText(source, 'comicId'),
      deviceKeyId: _requiredText(source, 'deviceKeyId'),
      licenseToken: _requiredText(source, 'licenseToken'),
      wrappedContentKey: _requiredText(source, 'wrappedContentKey'),
      keyAlgorithm: _requiredText(source, 'keyAlgorithm'),
      signingKeyId: _requiredText(source, 'signingKeyId'),
      packageSha256: _requiredText(source, 'packageSha256').toLowerCase(),
      packageSize: _requiredInt(source, 'packageSize'),
      formatVersion: _requiredInt(source, 'formatVersion'),
      offlineUntil: _requiredDate(source, 'offlineUntil'),
      serverTime: _requiredDate(source, 'serverTime'),
    );
  }
}

class CvPackPage {
  const CvPackPage({
    required this.pageNumber,
    required this.offset,
    required this.length,
    required this.nonce,
    required this.contentType,
    required this.plaintextLength,
    required this.pageSha256,
    required this.ciphertextSha256,
  });

  final int pageNumber;
  final int offset;
  final int length;
  final String nonce;
  final String contentType;
  final int plaintextLength;
  final String pageSha256;
  final String ciphertextSha256;

  factory CvPackPage.fromJson(Map<String, dynamic> json) => CvPackPage(
    pageNumber: _requiredInt(json, 'pageNumber'),
    offset: _requiredInt(json, 'offset'),
    length: _requiredInt(json, 'length'),
    nonce: _requiredText(json, 'nonce'),
    contentType: _requiredText(json, 'contentType'),
    plaintextLength: _requiredInt(json, 'plaintextLength'),
    pageSha256: _requiredText(json, 'pageSha256').toLowerCase(),
    ciphertextSha256: _requiredText(json, 'ciphertextSha256').toLowerCase(),
  );
}

class CvPackTranslation {
  const CvPackTranslation({
    required this.languageCode,
    required this.offset,
    required this.length,
    required this.nonce,
    required this.contentType,
    required this.plaintextLength,
    required this.translationSha256,
    required this.ciphertextSha256,
  });

  final String languageCode;
  final int offset;
  final int length;
  final String nonce;
  final String contentType;
  final int plaintextLength;
  final String translationSha256;
  final String ciphertextSha256;

  factory CvPackTranslation.fromJson(Map<String, dynamic> json) =>
      CvPackTranslation(
        languageCode: _requiredText(json, 'languageCode').toLowerCase(),
        offset: _requiredInt(json, 'offset'),
        length: _requiredInt(json, 'length'),
        nonce: _requiredText(json, 'nonce'),
        contentType: _requiredText(json, 'contentType'),
        plaintextLength: _requiredInt(json, 'plaintextLength'),
        translationSha256: _requiredText(
          json,
          'translationSha256',
        ).toLowerCase(),
        ciphertextSha256: _requiredText(json, 'ciphertextSha256').toLowerCase(),
      );
}

class CvPackManifest {
  const CvPackManifest({
    required this.version,
    required this.packageId,
    required this.chapterId,
    required this.comicId,
    required this.userId,
    required this.deviceKeyId,
    required this.deviceIdHash,
    required this.deviceKeySha256,
    required this.contentRevision,
    required this.offsetBase,
    required this.cipher,
    required this.tagLengthBits,
    required this.aadFormat,
    required this.payloadOffset,
    required this.pages,
    this.translationAadFormat,
    this.translations = const [],
  });

  static const magic = 'CVPK1';
  static const fixedHeaderLength = 9;
  static const maximumManifestBytes = 2 * 1024 * 1024;
  static const maximumPages = 200;
  static const maximumTranslations = 32;

  final int version;
  final String packageId;
  final String chapterId;
  final String comicId;
  final String userId;
  final String deviceKeyId;
  final String deviceIdHash;
  final String deviceKeySha256;
  final String contentRevision;
  final String offsetBase;
  final String cipher;
  final int tagLengthBits;
  final String aadFormat;
  final int payloadOffset;
  final List<CvPackPage> pages;
  final String? translationAadFormat;
  final List<CvPackTranslation> translations;

  int get pageCount => pages.length;

  List<String> get translationLanguages => translations
      .map((translation) => translation.languageCode)
      .toList(growable: false);

  CvPackPage page(int pageNumber) => pages.firstWhere(
    (entry) => entry.pageNumber == pageNumber,
    orElse: () => throw const OfflineDownloadException(
      'corrupted_package',
      'The downloaded chapter page is missing.',
    ),
  );

  CvPackTranslation translation(String languageCode) => translations.firstWhere(
    (entry) => entry.languageCode == languageCode.toLowerCase(),
    orElse: () => throw const OfflineDownloadException(
      'translation_not_downloaded',
      'This translation is not included in the downloaded chapter.',
    ),
  );

  static CvPackManifest parse({
    required List<int> header,
    required List<int> manifestBytes,
    required int packageLength,
  }) {
    if (header.length != fixedHeaderLength ||
        ascii.decode(header.take(5).toList(), allowInvalid: true) != magic) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter has an invalid package format.',
      );
    }
    final manifestLength =
        (header[5] << 24) | (header[6] << 16) | (header[7] << 8) | header[8];
    if (manifestLength <= 0 ||
        manifestLength > maximumManifestBytes ||
        manifestLength != manifestBytes.length) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter manifest is invalid.',
      );
    }
    final decoded = jsonDecode(utf8.decode(manifestBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter manifest is invalid.',
      );
    }
    final version = _requiredInt(decoded, 'version');
    final rawPages = decoded['pages'];
    if (rawPages is! List ||
        rawPages.isEmpty ||
        rawPages.length > maximumPages) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter does not contain readable pages.',
      );
    }
    final pages = rawPages
        .whereType<Map<String, dynamic>>()
        .map(CvPackPage.fromJson)
        .toList(growable: false);
    if (pages.length != rawPages.length) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter page index is invalid.',
      );
    }
    var translations = const <CvPackTranslation>[];
    final rawTranslations = decoded['translations'];
    if (version >= 2) {
      if (rawTranslations is! List ||
          rawTranslations.length > maximumTranslations) {
        throw const OfflineDownloadException(
          'corrupted_package',
          'The downloaded chapter translation index is invalid.',
        );
      }
      translations = rawTranslations
          .whereType<Map<String, dynamic>>()
          .map(CvPackTranslation.fromJson)
          .toList(growable: false);
      if (translations.length != rawTranslations.length ||
          _requiredInt(decoded, 'translationCount') != translations.length) {
        throw const OfflineDownloadException(
          'corrupted_package',
          'The downloaded chapter translation count is invalid.',
        );
      }
    } else if (rawTranslations is List && rawTranslations.isNotEmpty) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'This package version cannot contain translations.',
      );
    }
    final payloadOffset = fixedHeaderLength + manifestLength;
    final seenNumbers = <int>{};
    final ranges = <(int, int)>[];
    for (final page in pages) {
      final nonce = _decodeBase64Url(page.nonce);
      final absoluteStart = payloadOffset + page.offset;
      final absoluteEnd = absoluteStart + page.length;
      if (page.pageNumber < 1 ||
          !seenNumbers.add(page.pageNumber) ||
          page.offset < 0 ||
          page.length <= 16 ||
          nonce.length != 12 ||
          page.plaintextLength <= 0 ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(page.pageSha256) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(page.ciphertextSha256) ||
          absoluteStart < payloadOffset ||
          absoluteEnd > packageLength) {
        throw const OfflineDownloadException(
          'corrupted_package',
          'The downloaded chapter page index is invalid.',
        );
      }
      ranges.add((absoluteStart, absoluteEnd));
    }
    final seenLanguages = <String>{};
    for (final translation in translations) {
      final nonce = _decodeBase64Url(translation.nonce);
      final absoluteStart = payloadOffset + translation.offset;
      final absoluteEnd = absoluteStart + translation.length;
      if (!RegExp(r'^[a-z0-9]{2,16}$').hasMatch(translation.languageCode) ||
          !seenLanguages.add(translation.languageCode) ||
          translation.offset < 0 ||
          translation.length <= 16 ||
          nonce.length != 12 ||
          translation.plaintextLength <= 0 ||
          translation.contentType.toLowerCase() != 'application/json' ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(translation.translationSha256) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(translation.ciphertextSha256) ||
          absoluteStart < payloadOffset ||
          absoluteEnd > packageLength) {
        throw const OfflineDownloadException(
          'corrupted_package',
          'The downloaded chapter translation index is invalid.',
        );
      }
      ranges.add((absoluteStart, absoluteEnd));
    }
    ranges.sort((left, right) => left.$1.compareTo(right.$1));
    for (var index = 1; index < ranges.length; index++) {
      if (ranges[index].$1 < ranges[index - 1].$2) {
        throw const OfflineDownloadException(
          'corrupted_package',
          'The downloaded chapter contains overlapping payload data.',
        );
      }
    }
    final declaredCount = _requiredInt(decoded, 'pageCount');
    final sortedNumbers = seenNumbers.toList()..sort();
    if (declaredCount != pages.length ||
        List.generate(pages.length, (index) => index + 1).asMap().entries.any(
          (entry) => sortedNumbers[entry.key] != entry.value,
        )) {
      throw const OfflineDownloadException(
        'corrupted_package',
        'The downloaded chapter page count is invalid.',
      );
    }
    return CvPackManifest(
      version: version,
      packageId: _requiredText(decoded, 'packageId'),
      chapterId: _requiredText(decoded, 'chapterId'),
      comicId: _requiredText(decoded, 'comicId'),
      userId: _requiredText(decoded, 'userId'),
      deviceKeyId: _requiredText(decoded, 'deviceKeyId'),
      deviceIdHash: _requiredText(decoded, 'deviceIdHash').toLowerCase(),
      deviceKeySha256: _requiredText(decoded, 'deviceKeySha256').toLowerCase(),
      contentRevision: _requiredText(decoded, 'contentRevision'),
      offsetBase: _requiredText(decoded, 'offsetBase'),
      cipher: _requiredText(decoded, 'cipher'),
      tagLengthBits: _requiredInt(decoded, 'tagLengthBits'),
      aadFormat: _requiredText(decoded, 'aadFormat'),
      payloadOffset: payloadOffset,
      pages: pages,
      translationAadFormat: decoded['translationAadFormat']?.toString(),
      translations: translations,
    );
  }
}

class OfflineDownloadEntry {
  const OfflineDownloadEntry({
    required this.chapterId,
    required this.comicId,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.comicTitle,
    required this.licenseToken,
    required this.wrappedContentKey,
    required this.keyAlgorithm,
    required this.packageSha256,
    required this.deviceKeyId,
    required this.deviceKeySha256,
    required this.downloadedAt,
    required this.offlineUntil,
    required this.sizeBytes,
    required this.manifest,
  });

  final String chapterId;
  final String comicId;
  final String chapterNumber;
  final String chapterTitle;
  final String comicTitle;
  final String licenseToken;
  final String wrappedContentKey;
  final String keyAlgorithm;
  final String packageSha256;
  final String deviceKeyId;
  final String deviceKeySha256;
  final DateTime downloadedAt;
  final DateTime offlineUntil;
  final int sizeBytes;
  final CvPackManifest manifest;

  OfflineDownloadEntry copyWith({
    String? licenseToken,
    String? wrappedContentKey,
    String? keyAlgorithm,
    String? packageSha256,
    DateTime? downloadedAt,
    DateTime? offlineUntil,
    int? sizeBytes,
    CvPackManifest? manifest,
  }) => OfflineDownloadEntry(
    chapterId: chapterId,
    comicId: comicId,
    chapterNumber: chapterNumber,
    chapterTitle: chapterTitle,
    comicTitle: comicTitle,
    licenseToken: licenseToken ?? this.licenseToken,
    wrappedContentKey: wrappedContentKey ?? this.wrappedContentKey,
    keyAlgorithm: keyAlgorithm ?? this.keyAlgorithm,
    packageSha256: packageSha256 ?? this.packageSha256,
    deviceKeyId: deviceKeyId,
    deviceKeySha256: deviceKeySha256,
    downloadedAt: downloadedAt ?? this.downloadedAt,
    offlineUntil: offlineUntil ?? this.offlineUntil,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    manifest: manifest ?? this.manifest,
  );

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'comicId': comicId,
    'chapterNumber': chapterNumber,
    'chapterTitle': chapterTitle,
    'comicTitle': comicTitle,
    'licenseToken': licenseToken,
    'wrappedContentKey': wrappedContentKey,
    'keyAlgorithm': keyAlgorithm,
    'packageSha256': packageSha256,
    'deviceKeyId': deviceKeyId,
    'deviceKeySha256': deviceKeySha256,
    'downloadedAt': downloadedAt.toUtc().toIso8601String(),
    'offlineUntil': offlineUntil.toUtc().toIso8601String(),
    'sizeBytes': sizeBytes,
    'manifest': {
      'version': manifest.version,
      'packageId': manifest.packageId,
      'chapterId': manifest.chapterId,
      'comicId': manifest.comicId,
      'userId': manifest.userId,
      'deviceKeyId': manifest.deviceKeyId,
      'deviceIdHash': manifest.deviceIdHash,
      'deviceKeySha256': manifest.deviceKeySha256,
      'contentRevision': manifest.contentRevision,
      'offsetBase': manifest.offsetBase,
      'cipher': manifest.cipher,
      'tagLengthBits': manifest.tagLengthBits,
      'aadFormat': manifest.aadFormat,
      'payloadOffset': manifest.payloadOffset,
      if (manifest.translationAadFormat != null)
        'translationAadFormat': manifest.translationAadFormat,
      'pages': [
        for (final page in manifest.pages)
          {
            'pageNumber': page.pageNumber,
            'offset': page.offset,
            'length': page.length,
            'nonce': page.nonce,
            'contentType': page.contentType,
            'plaintextLength': page.plaintextLength,
            'pageSha256': page.pageSha256,
            'ciphertextSha256': page.ciphertextSha256,
          },
      ],
      'translations': [
        for (final translation in manifest.translations)
          {
            'languageCode': translation.languageCode,
            'offset': translation.offset,
            'length': translation.length,
            'nonce': translation.nonce,
            'contentType': translation.contentType,
            'plaintextLength': translation.plaintextLength,
            'translationSha256': translation.translationSha256,
            'ciphertextSha256': translation.ciphertextSha256,
          },
      ],
    },
  };

  factory OfflineDownloadEntry.fromJson(Map<String, dynamic> json) {
    final manifestJson = json['manifest'];
    if (manifestJson is! Map<String, dynamic>) {
      throw const FormatException('Missing offline manifest');
    }
    final rawPages = manifestJson['pages'];
    if (rawPages is! List) throw const FormatException('Missing pages');
    final pages = rawPages
        .whereType<Map<String, dynamic>>()
        .map(CvPackPage.fromJson)
        .toList(growable: false);
    final rawTranslations = manifestJson['translations'];
    final translations = rawTranslations is List
        ? rawTranslations
              .whereType<Map<String, dynamic>>()
              .map(CvPackTranslation.fromJson)
              .toList(growable: false)
        : const <CvPackTranslation>[];
    return OfflineDownloadEntry(
      chapterId: _requiredText(json, 'chapterId'),
      comicId: _requiredText(json, 'comicId'),
      chapterNumber: (json['chapterNumber'] ?? '').toString(),
      chapterTitle: _requiredText(json, 'chapterTitle'),
      comicTitle: _requiredText(json, 'comicTitle'),
      licenseToken: _requiredText(json, 'licenseToken'),
      wrappedContentKey: _requiredText(json, 'wrappedContentKey'),
      keyAlgorithm: _requiredText(json, 'keyAlgorithm'),
      packageSha256: _requiredText(json, 'packageSha256'),
      deviceKeyId: _requiredText(json, 'deviceKeyId'),
      deviceKeySha256: _requiredText(json, 'deviceKeySha256'),
      downloadedAt: _requiredDate(json, 'downloadedAt'),
      offlineUntil: _requiredDate(json, 'offlineUntil'),
      sizeBytes: _requiredInt(json, 'sizeBytes'),
      manifest: CvPackManifest(
        version: _requiredInt(manifestJson, 'version'),
        packageId: _requiredText(manifestJson, 'packageId'),
        chapterId: _requiredText(manifestJson, 'chapterId'),
        comicId: _requiredText(manifestJson, 'comicId'),
        userId: _requiredText(manifestJson, 'userId'),
        deviceKeyId: _requiredText(manifestJson, 'deviceKeyId'),
        deviceIdHash: _requiredText(manifestJson, 'deviceIdHash').toLowerCase(),
        deviceKeySha256: _requiredText(
          manifestJson,
          'deviceKeySha256',
        ).toLowerCase(),
        contentRevision: _requiredText(manifestJson, 'contentRevision'),
        offsetBase: _requiredText(manifestJson, 'offsetBase'),
        cipher: _requiredText(manifestJson, 'cipher'),
        tagLengthBits: _requiredInt(manifestJson, 'tagLengthBits'),
        aadFormat: _requiredText(manifestJson, 'aadFormat'),
        payloadOffset: _requiredInt(manifestJson, 'payloadOffset'),
        pages: pages,
        translationAadFormat: manifestJson['translationAadFormat']?.toString(),
        translations: translations,
      ),
    );
  }
}

Map<String, dynamic> _unwrapMap(Map<String, dynamic> json) {
  final data = json['data'];
  return data is Map<String, dynamic> ? data : json;
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim() ?? '';
  if (value.isEmpty) throw FormatException('Missing $key');
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('Missing $key');
  return parsed;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(json[key]?.toString() ?? '');
  if (parsed == null) throw FormatException('Missing $key');
  return parsed.toUtc();
}

DateTime _epochDate(Object? value, String key) {
  final seconds = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (seconds == null) throw FormatException('Missing $key');
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

DateTime _dateOrEpoch(Object? value, String key) {
  if (value is num) return _epochDate(value, key);
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toUtc() ?? _epochDate(value, key);
}

String _audience(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is List && value.isNotEmpty) return value.first.toString();
  throw const FormatException('Missing aud');
}

List<int> decodeBase64Url(String value) => _decodeBase64Url(value);

List<int> _decodeBase64Url(String value) {
  final normalized = base64Url.normalize(value.trim());
  return base64Url.decode(normalized);
}
