import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'offline_decrypted_cache_contract.dart';

class PrivateOfflineDecryptedPageCache implements OfflineDecryptedPageCache {
  const PrivateOfflineDecryptedPageCache();

  @override
  Future<Uint8List?> read({
    required String accountScope,
    required String chapterId,
    required String packageSha256,
    required int pageNumber,
  }) async {
    final file = await _pageFile(
      accountScope: accountScope,
      chapterId: chapterId,
      packageSha256: packageSha256,
      pageNumber: pageNumber,
    );
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write({
    required String accountScope,
    required String chapterId,
    required String packageSha256,
    required int pageNumber,
    required Uint8List bytes,
  }) async {
    final file = await _pageFile(
      accountScope: accountScope,
      chapterId: chapterId,
      packageSha256: packageSha256,
      pageNumber: pageNumber,
    );
    await file.parent.create(recursive: true);
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(bytes, flush: false);
    if (await file.exists()) await file.delete();
    await partial.rename(file.path);
  }

  @override
  Future<void> deleteChapter({
    required String accountScope,
    required String chapterId,
  }) async {
    final directory = await _chapterDirectory(accountScope, chapterId);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<void> clearAll() async {
    final root = await _rootDirectory();
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<File> _pageFile({
    required String accountScope,
    required String chapterId,
    required String packageSha256,
    required int pageNumber,
  }) async {
    final chapter = await _chapterDirectory(accountScope, chapterId);
    final revision = _hash(packageSha256).substring(0, 16);
    return File(
      '${chapter.path}${Platform.pathSeparator}$revision-$pageNumber.page',
    );
  }

  Future<Directory> _chapterDirectory(
    String accountScope,
    String chapterId,
  ) async {
    final root = await _rootDirectory();
    return Directory(
      '${root.path}${Platform.pathSeparator}${_hash(accountScope)}'
      '${Platform.pathSeparator}${_hash(chapterId)}',
    );
  }

  Future<Directory> _rootDirectory() async {
    final root = await getTemporaryDirectory();
    return Directory(
      '${root.path}${Platform.pathSeparator}comiverse_decrypted_v1',
    );
  }

  String _hash(String value) => sha256.convert(value.codeUnits).toString();
}
