class LoginDevice {
  const LoginDevice({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.current,
    this.verifiedAt,
    this.lastSeenAt,
  });

  final String id;
  final String deviceName;
  final String platform;
  final bool current;
  final DateTime? verifiedAt;
  final DateTime? lastSeenAt;

  factory LoginDevice.fromJson(Map<String, dynamic> json) => LoginDevice(
    id: (json['id'] ?? '').toString(),
    deviceName: (json['deviceName'] ?? 'Mobile device').toString(),
    platform: (json['platform'] ?? 'android').toString().toLowerCase(),
    current: json['current'] == true,
    verifiedAt: DateTime.tryParse((json['verifiedAt'] ?? '').toString()),
    lastSeenAt: DateTime.tryParse((json['lastSeenAt'] ?? '').toString()),
  );
}

class DeviceOtpChallenge {
  const DeviceOtpChallenge({required this.id, required this.expiresAt});

  final String id;
  final DateTime expiresAt;

  factory DeviceOtpChallenge.fromJson(Map<String, dynamic> json) {
    final source = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return DeviceOtpChallenge(
      id: (source['challengeId'] ?? '').toString(),
      expiresAt:
          DateTime.tryParse((source['expiresAt'] ?? '').toString()) ??
          DateTime.now().add(const Duration(minutes: 5)),
    );
  }
}

class LoginDeviceVerificationRequired implements Exception {
  const LoginDeviceVerificationRequired({
    required this.challengeId,
    required this.expiresAt,
    required this.devices,
  });

  final String challengeId;
  final DateTime expiresAt;
  final List<LoginDevice> devices;

  @override
  String toString() =>
      'This account is already signed in on the maximum number of devices.';
}
