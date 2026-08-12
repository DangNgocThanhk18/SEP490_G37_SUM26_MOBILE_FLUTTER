class NotificationPreferences {
  const NotificationPreferences({
    required this.role,
    required this.availableKeys,
    required this.values,
  });

  final String role;
  final List<String> availableKeys;
  final Map<String, bool> values;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final rawKeys = json['availableKeys'];
    final rawValues = json['preferences'];
    return NotificationPreferences(
      role: (json['role'] ?? '').toString(),
      availableKeys: rawKeys is List
          ? rawKeys.map((item) => item.toString()).toList(growable: false)
          : const [],
      values: rawValues is Map
          ? rawValues.map(
              (key, value) => MapEntry(key.toString(), value == true),
            )
          : const {},
    );
  }
}

class PushDeviceStatus {
  const PushDeviceStatus({
    required this.serverConfigured,
    required this.registeredDeviceCount,
  });

  final bool serverConfigured;
  final int registeredDeviceCount;

  bool get ready => serverConfigured && registeredDeviceCount > 0;

  factory PushDeviceStatus.fromJson(Map<String, dynamic> json) =>
      PushDeviceStatus(
        serverConfigured: json['serverConfigured'] == true,
        registeredDeviceCount:
            (json['registeredDeviceCount'] as num?)?.toInt() ?? 0,
      );
}
