class UserProfile {
  const UserProfile({
    required this.username,
    required this.email,
    this.fullName,
    this.role,
    this.avatarUrl,
    this.backgroundImageUrl,
    this.premiumPlan,
    this.premiumExpiresAt,
    this.premiumActive = false,
  });

  final String username;
  final String email;
  final String? fullName;
  final String? role;
  final String? avatarUrl;
  final String? backgroundImageUrl;
  final String? premiumPlan;
  final DateTime? premiumExpiresAt;
  final bool premiumActive;

  String get displayName {
    final cleanFullName = fullName?.trim();
    if (cleanFullName != null && cleanFullName.isNotEmpty) {
      return cleanFullName;
    }
    return username;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: (json['username'] ?? 'reader').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: json['fullName']?.toString(),
      role: json['role']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      backgroundImageUrl: json['backgroundImageUrl']?.toString(),
      premiumPlan: json['premiumPlan']?.toString(),
      premiumExpiresAt: DateTime.tryParse(
        (json['premiumExpiresAt'] ?? '').toString(),
      ),
      premiumActive: json['premiumActive'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'fullName': fullName,
      'role': role,
      'avatarUrl': avatarUrl,
      'backgroundImageUrl': backgroundImageUrl,
      'premiumPlan': premiumPlan,
      'premiumExpiresAt': premiumExpiresAt?.toIso8601String(),
      'premiumActive': premiumActive,
    };
  }
}
