enum UserRole { admin, teacher, parent }

class UserModel {
  final int? id;
  final String uid; 
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String status; // 'active' or 'deactivated'
  final String createdAt;
  final String updatedAt;
  final bool isSynced;

  UserModel({
    this.id,
    required this.uid,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'email': email,
      'password': password,
      'role': role.name,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.parent,
      ),
      status: map['status'] ?? 'active',
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  UserModel copyWith({
    int? id,
    String? uid,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    String? status,
    String? createdAt,
    String? updatedAt,
    bool? isSynced,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
