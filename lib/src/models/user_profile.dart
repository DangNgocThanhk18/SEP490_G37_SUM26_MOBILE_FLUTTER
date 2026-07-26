class UserProfile {
  const UserProfile({
    this.userId,
    required this.username,
    required this.email,
    this.fullName,
    this.role,
    this.avatarUrl,
    this.backgroundImageUrl,
    this.dateOfBirth,
    this.bio,
    this.premiumPlan,
    this.premiumExpiresAt,
    this.premiumActive = false,
  });

  final String? userId;
  final String username;
  final String email;
  final String? fullName;
  final String? role;
  final String? avatarUrl;
  final String? backgroundImageUrl;
  final DateTime? dateOfBirth;
  final String? bio;
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
      userId: json['userId']?.toString(),
      username: (json['username'] ?? 'reader').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: json['fullName']?.toString(),
      role: json['role']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      backgroundImageUrl: json['backgroundImageUrl']?.toString(),
      dateOfBirth: DateTime.tryParse((json['dateOfBirth'] ?? '').toString()),
      bio: json['bio']?.toString(),
      premiumPlan: json['premiumPlan']?.toString(),
      premiumExpiresAt: DateTime.tryParse(
        (json['premiumExpiresAt'] ?? '').toString(),
      ),
      premiumActive: json['premiumActive'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'fullName': fullName,
      'role': role,
      'avatarUrl': avatarUrl,
      'backgroundImageUrl': backgroundImageUrl,
      'dateOfBirth': dateOfBirth?.toIso8601String().split('T').first,
      'bio': bio,
      'premiumPlan': premiumPlan,
      'premiumExpiresAt': premiumExpiresAt?.toIso8601String(),
      'premiumActive': premiumActive,
    };
  }
}
