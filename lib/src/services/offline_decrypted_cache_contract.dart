import 'dart:typed_data';

abstract interface class OfflineDecryptedPageCache {
  /// Reads and writes only platform-sealed page frames. Plain image bytes must
  /// never be persisted by an implementation of this cache.
  Future<Uint8List?> read({
    required String accountScope,
    required String chapterId,
    required String packageSha256,
    required int pageNumber,
  });

  Future<void> write({
    required String accountScope,
    required String chapterId,
    required String packageSha256,
    required int pageNumber,
    required Uint8List bytes,
  });

  Future<void> deleteChapter({
    required String accountScope,
    required String chapterId,
  });

  Future<void> clearAll();
}
