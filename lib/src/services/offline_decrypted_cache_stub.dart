import 'dart:typed_data';

import 'offline_decrypted_cache_contract.dart';

class PrivateOfflineDecryptedPageCache implements OfflineDecryptedPageCache {
  const PrivateOfflineDecryptedPageCache();

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> deleteChapter({
    required String accountScope,
    required String chapterId,
  }) async {}

  @override
  Future<Uint8List?> read({
    required String accountScope,
    required String chapterId,
    required String packageSha256,
    required int pageNumber,
  }) async => null;

  @override
  Future<void> write({
    required String accountScope,
    required String chapterId,
    required String packageSha256,
    required int pageNumber,
    required Uint8List bytes,
  }) async {}
}
