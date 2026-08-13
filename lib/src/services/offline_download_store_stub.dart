import 'dart:typed_data';

import 'offline_download_store_contract.dart';

class PrivateOfflineDownloadStore implements OfflineDownloadStore {
  const PrivateOfflineDownloadStore();

  @override
  Future<bool> isSupported() async => false;

  Never _unsupported() => throw UnsupportedError(
    'Encrypted offline downloads are only supported by the Android and iOS apps.',
  );

  @override
  Future<StagedOfflinePackage> stagePackage({
    required String accountScope,
    required String chapterId,
    required Stream<List<int>> bytes,
    int maximumBytes = 150 * 1024 * 1024,
  }) async => _unsupported();

  @override
  Future<void> commitPackage(StagedOfflinePackage package) async =>
      _unsupported();

  @override
  Future<String> packagePath({
    required String accountScope,
    required String chapterId,
  }) async => _unsupported();

  @override
  Future<void> discardStagedPackage(StagedOfflinePackage package) async =>
      _unsupported();

  @override
  Future<int> packageLength({
    required String accountScope,
    required String chapterId,
    bool staged = false,
  }) async => _unsupported();

  @override
  Future<Uint8List> readRange({
    required String accountScope,
    required String chapterId,
    required int offset,
    required int length,
    bool staged = false,
  }) async => _unsupported();

  @override
  Future<String> packageSha256({
    required String accountScope,
    required String chapterId,
  }) async => _unsupported();

  @override
  Future<bool> packageExists({
    required String accountScope,
    required String chapterId,
  }) async => false;

  @override
  Future<void> deletePackage({
    required String accountScope,
    required String chapterId,
  }) async {}

  @override
  Future<void> deleteAccountPackages(String accountScope) async {}
}
