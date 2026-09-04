enum UserRole { admin, teacher, parent }

class UserModel {
  final int? id;
  final String name;
  final String email;
  final String password;
  final UserRole role;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'role': role.name,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
      role: UserRole.values.firstWhere((e) => e.name == map['role']),
    );
  }
}
