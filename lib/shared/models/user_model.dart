enum UserRole { admin, teacher, parent }

class UserModel {
  final int? id;
  final String uid; // Added for unique identification
  final String name;
  final String email;
  final String password;
  final UserRole role;

  UserModel({
    this.id,
    required this.uid,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'email': email,
      'password': password,
      'role': role.name,
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
    );
  }
}
