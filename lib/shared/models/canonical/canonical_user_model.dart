/// Canonical User model (refined).
/// 
/// This replaces the existing UserModel with a security-focused version:
/// - NO PASSWORD FIELD (passwords only in Firebase Auth)
/// - Only Firebase UID for identification
/// - Metadata and role/consent status

class CanonicalUser {
  final String uid; // Firebase Auth UID (unique identifier)
  final String name;
  final String email;
  final UserRoleType role;
  final String status; // 'active', 'deactivated', 'pending'
  final String? centerId; // Center assignment (for teachers)
  final String? phone;
  final String? profilePhotoUrl;
  final bool termsAccepted;
  final DateTime? termsAcceptedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fcmToken; // For push notifications
  final DateTime? lastLoginAt;
  final Map<String, dynamic>? metadata; // Additional fields

  CanonicalUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.centerId,
    this.phone,
    this.profilePhotoUrl,
    this.termsAccepted = false,
    this.termsAcceptedAt,
    required this.createdAt,
    required this.updatedAt,
    this.fcmToken,
    this.lastLoginAt,
    this.metadata,
  });

  factory CanonicalUser.fromMap(Map<String, dynamic> map) {
    return CanonicalUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRoleType.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => UserRoleType.parent,
      ),
      status: map['status'] ?? 'active',
      centerId: map['center_id'] as String?,
      phone: map['phone'] as String?,
      profilePhotoUrl: map['profile_photo_url'] as String?,
      termsAccepted: (map['terms_accepted'] ?? 0) == 1,
      termsAcceptedAt: map['terms_accepted_at'] != null
          ? DateTime.parse(map['terms_accepted_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
      fcmToken: map['fcm_token'] as String?,
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.parse(map['last_login_at'] as String)
          : null,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'status': status,
      'center_id': centerId,
      'phone': phone,
      'profile_photo_url': profilePhotoUrl,
      'terms_accepted': termsAccepted ? 1 : 0,
      'terms_accepted_at': termsAcceptedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'fcm_token': fcmToken,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  CanonicalUser copyWith({
    String? uid,
    String? name,
    String? email,
    UserRoleType? role,
    String? status,
    String? centerId,
    String? phone,
    String? profilePhotoUrl,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fcmToken,
    DateTime? lastLoginAt,
    Map<String, dynamic>? metadata,
  }) {
    return CanonicalUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      centerId: centerId ?? this.centerId,
      phone: phone ?? this.phone,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fcmToken: fcmToken ?? this.fcmToken,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'CanonicalUser($email, role=$role, status=$status)';
}

enum UserRoleType { admin, teacher, parent }
