import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'offline_download_store_contract.dart';

class PrivateOfflineDownloadStore implements OfflineDownloadStore {
  const PrivateOfflineDownloadStore();

  @override
  Future<bool> isSupported() async => Platform.isAndroid || Platform.isIOS;

  @override
  Future<StagedOfflinePackage> stagePackage({
    required String accountScope,
    required String chapterId,
    required Stream<List<int>> bytes,
    int maximumBytes = 150 * 1024 * 1024,
  }) async {
    final directory = await _accountDirectory(accountScope);
    await directory.create(recursive: true);
    final stagedFile = File(_stagedPath(directory, chapterId));
    if (await stagedFile.exists()) await stagedFile.delete();
    final output = stagedFile.openWrite(mode: FileMode.writeOnly);
    final digestSink = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digestSink);
    var total = 0;
    try {
      await for (final chunk in bytes) {
        total += chunk.length;
        if (total > maximumBytes) {
          throw const FileSystemException(
            'Offline package exceeds the 150 MB safety limit.',
          );
        }
        digestInput.add(chunk);
        output.add(chunk);
      }
      digestInput.close();
      await output.flush();
      await output.close();
    } catch (_) {
      await output.close().catchError((_) {});
      if (await stagedFile.exists()) await stagedFile.delete();
      rethrow;
    }
    if (total <= 0 || digestSink.value == null) {
      if (await stagedFile.exists()) await stagedFile.delete();
      throw const FileSystemException('Offline package is empty.');
    }
    return StagedOfflinePackage(
      accountScope: accountScope,
      chapterId: chapterId,
      sha256: digestSink.value.toString(),
      length: total,
    );
  }

  @override
  Future<void> commitPackage(StagedOfflinePackage package) async {
    final directory = await _accountDirectory(package.accountScope);
    final staged = File(_stagedPath(directory, package.chapterId));
    if (!await staged.exists()) {
      throw const FileSystemException('Staged offline package is missing.');
    }
    final current = File(_packagePath(directory, package.chapterId));
    final backup = File('${current.path}.previous');
    if (await backup.exists()) await backup.delete();
    if (await current.exists()) await current.rename(backup.path);
    try {
      await staged.rename(current.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await backup.exists() && !await current.exists()) {
        await backup.rename(current.path);
      }
      rethrow;
    }
  }

  @override
  Future<void> discardStagedPackage(StagedOfflinePackage package) async {
    final directory = await _accountDirectory(package.accountScope);
    final staged = File(_stagedPath(directory, package.chapterId));
    if (await staged.exists()) await staged.delete();
  }

  @override
  Future<int> packageLength({
    required String accountScope,
    required String chapterId,
    bool staged = false,
  }) async {
    final directory = await _accountDirectory(accountScope);
    return File(
      staged
          ? _stagedPath(directory, chapterId)
          : _packagePath(directory, chapterId),
    ).length();
  }

  @override
  Future<Uint8List> readRange({
    required String accountScope,
    required String chapterId,
    required int offset,
    required int length,
    bool staged = false,
  }) async {
    if (offset < 0 || length <= 0 || length > 12 * 1024 * 1024 + 16) {
      throw const FileSystemException('Invalid offline package range.');
    }
    final directory = await _accountDirectory(accountScope);
    final file = File(
      staged
          ? _stagedPath(directory, chapterId)
          : _packagePath(directory, chapterId),
    );
    final handle = await file.open(mode: FileMode.read);
    try {
      await handle.setPosition(offset);
      final bytes = await handle.read(length);
      if (bytes.length != length) {
        throw const FileSystemException('Offline package ended unexpectedly.');
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  @override
  Future<String> packageSha256({
    required String accountScope,
    required String chapterId,
  }) async {
    final directory = await _accountDirectory(accountScope);
    final file = File(_packagePath(directory, chapterId));
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    final value = sink.value;
    if (value == null) throw const FileSystemException('Cannot hash package.');
    return value.toString();
  }

  @override
  Future<bool> packageExists({
    required String accountScope,
    required String chapterId,
  }) async {
    final directory = await _accountDirectory(accountScope);
    return File(_packagePath(directory, chapterId)).exists();
  }

  @override
  Future<void> deletePackage({
    required String accountScope,
    required String chapterId,
  }) async {
    final directory = await _accountDirectory(accountScope);
    for (final suffix in ['', '.part', '.previous']) {
      final path = suffix == '.part'
          ? _stagedPath(directory, chapterId)
          : '${_packagePath(directory, chapterId)}$suffix';
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> deleteAccountPackages(String accountScope) async {
    final directory = await _accountDirectory(accountScope);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<Directory> _accountDirectory(String accountScope) async {
    final root = await getApplicationSupportDirectory();
    final digest = sha256.convert(accountScope.codeUnits).toString();
    return Directory(
      '${root.path}${Platform.pathSeparator}offline_v1${Platform.pathSeparator}$digest',
    );
  }

  String _safeChapter(String chapterId) =>
      sha256.convert(chapterId.codeUnits).toString();

  String _packagePath(Directory directory, String chapterId) =>
      '${directory.path}${Platform.pathSeparator}${_safeChapter(chapterId)}.cvpack';

  String _stagedPath(Directory directory, String chapterId) =>
      '${_packagePath(directory, chapterId)}.part';
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
