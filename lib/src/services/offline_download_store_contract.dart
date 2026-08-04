import 'dart:typed_data';

class StagedOfflinePackage {
  const StagedOfflinePackage({
    required this.accountScope,
    required this.chapterId,
    required this.sha256,
    required this.length,
  });

  final String accountScope;
  final String chapterId;
  final String sha256;
  final int length;
}

abstract interface class OfflineDownloadStore {
  Future<bool> isSupported();

  Future<StagedOfflinePackage> stagePackage({
    required String accountScope,
    required String chapterId,
    required Stream<List<int>> bytes,
    int maximumBytes = 150 * 1024 * 1024,
  });

  Future<void> commitPackage(StagedOfflinePackage package);

  Future<void> discardStagedPackage(StagedOfflinePackage package);

  Future<int> packageLength({
    required String accountScope,
    required String chapterId,
    bool staged = false,
  });

  Future<Uint8List> readRange({
    required String accountScope,
    required String chapterId,
    required int offset,
    required int length,
    bool staged = false,
  });

  Future<String> packageSha256({
    required String accountScope,
    required String chapterId,
  });

  Future<bool> packageExists({
    required String accountScope,
    required String chapterId,
  });

  Future<void> deletePackage({
    required String accountScope,
    required String chapterId,
  });

  Future<void> deleteAccountPackages(String accountScope);
}
