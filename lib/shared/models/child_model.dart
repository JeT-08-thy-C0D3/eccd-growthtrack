class ChildModel {
  final int? id;
  final String name;
  final String dob; // Date of Birth
  final String gender;
  final int teacherId;
  final int parentId;

  ChildModel({
    this.id,
    required this.name,
    required this.dob,
    required this.gender,
    required this.teacherId,
    required this.parentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dob': dob,
      'gender': gender,
      'teacher_id': teacherId,
      'parent_id': parentId,
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    return ChildModel(
      id: map['id'],
      name: map['name'],
      dob: map['dob'],
      gender: map['gender'],
      teacherId: map['teacher_id'],
      parentId: map['parent_id'],
    );
  }
}
