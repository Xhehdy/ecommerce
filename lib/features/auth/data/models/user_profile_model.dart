class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? matricNumber;
  final String? faculty;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.matricNumber,
    this.faculty,
    this.phone,
    this.avatarUrl,
    this.createdAt,
  });

  String get displayName {
    final trimmedName = fullName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return email;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      matricNumber: json['matric_number'] as String?,
      faculty: json['faculty'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}
