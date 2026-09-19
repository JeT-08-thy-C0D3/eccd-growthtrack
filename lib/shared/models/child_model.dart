class ChildModel {
  final int? id;
  final String childId;
  final String firstName;
  final String lastName;
  final String birthDate;
  final int age;
  final String gender;
  final String address;
  final String parentName;
  final String teacherName;
  final String updatedAt;
  final bool isSynced;

  ChildModel({
    this.id,
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.age,
    required this.gender,
    required this.address,
    required this.parentName,
    required this.teacherName,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'first_name': firstName,
      'last_name': lastName,
      'birth_date': birthDate,
      'age': age,
      'gender': gender,
      'address': address,
      'parent_name': parentName,
      'teacher_name': teacherName,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    return ChildModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      birthDate: map['birth_date'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      address: map['address'] ?? '',
      parentName: map['parent_name'] ?? '',
      teacherName: map['teacher_name'] ?? '',
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  ChildModel copyWith({
    int? id,
    String? childId,
    String? firstName,
    String? lastName,
    String? birthDate,
    int? age,
    String? gender,
    String? address,
    String? parentName,
    String? teacherName,
    String? updatedAt,
    bool? isSynced,
  }) {
    return ChildModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      parentName: parentName ?? this.parentName,
      teacherName: teacherName ?? this.teacherName,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
