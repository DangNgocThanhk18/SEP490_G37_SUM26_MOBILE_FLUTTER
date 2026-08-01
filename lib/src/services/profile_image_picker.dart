import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

enum ProfileImageKind { avatar, background }

class ProfileImageSelection {
  const ProfileImageSelection({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

class ProfileImageSelectionException implements Exception {
  const ProfileImageSelectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class ProfileImagePicker {
  Future<ProfileImageSelection?> pick(ProfileImageKind kind);
}

class DeviceProfileImagePicker implements ProfileImagePicker {
  const DeviceProfileImagePicker();

  static const _avatarLimit = 2 * 1024 * 1024;
  static const _backgroundLimit = 4 * 1024 * 1024;

  @override
  Future<ProfileImageSelection?> pick(ProfileImageKind kind) async {
    try {
      final picker = ImagePicker();
      XFile? file;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final lostData = await picker.retrieveLostData();
        if (!lostData.isEmpty) {
          final recoveredFiles = lostData.files;
          if (recoveredFiles != null && recoveredFiles.isNotEmpty) {
            file = recoveredFiles.first;
          } else if (lostData.exception != null) {
            throw const ProfileImageSelectionException(
              'Could not open the selected image.',
            );
          }
        }
      }
      file ??= await picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return null;

      final limit = kind == ProfileImageKind.avatar
          ? _avatarLimit
          : _backgroundLimit;
      if (await file.length() > limit) {
        throw ProfileImageSelectionException(
          kind == ProfileImageKind.avatar
              ? 'Avatar image must be 2MB or smaller.'
              : 'Background image must be 4MB or smaller.',
        );
      }

      final bytes = await file.readAsBytes();
      final fileType = _resolveFileType(file.name, bytes);
      if (fileType == null) {
        throw const ProfileImageSelectionException(
          'Please choose a JPG, PNG, GIF, or WebP image.',
        );
      }

      return ProfileImageSelection(
        bytes: bytes,
        fileName: fileType.fileName,
        contentType: fileType.contentType,
      );
    } on ProfileImageSelectionException {
      rethrow;
    } catch (_) {
      throw const ProfileImageSelectionException(
        'Could not open the selected image.',
      );
    }
  }

  _ProfileImageFileType? _resolveFileType(String name, Uint8List bytes) {
    final detected = _detectImageType(bytes);
    if (detected == null) return null;

    final normalizedName = name.trim();
    final dot = normalizedName.lastIndexOf('.');
    final baseName =
        (dot > 0 ? normalizedName.substring(0, dot) : normalizedName).trim();
    return _ProfileImageFileType(
      fileName:
          '${baseName.isEmpty ? 'profile-image' : baseName}.${detected.extension}',
      contentType: detected.contentType,
    );
  }

  _DetectedImageType? _detectImageType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return const _DetectedImageType('jpg', 'image/jpeg');
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return const _DetectedImageType('png', 'image/png');
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return const _DetectedImageType('gif', 'image/gif');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return const _DetectedImageType('webp', 'image/webp');
    }
    return null;
  }
}

class _DetectedImageType {
  const _DetectedImageType(this.extension, this.contentType);

  final String extension;
  final String contentType;
}

class _ProfileImageFileType {
  const _ProfileImageFileType({
    required this.fileName,
    required this.contentType,
  });

  final String fileName;
  final String contentType;
}
