enum ChildSection {
  ited('ITED', '0–2 years old'),
  preKinder1('Pre-Kinder 1', '3 years old'),
  preKinder2('Pre-Kinder 2', '4–5 years old');

  const ChildSection(this.label, this.ageRange);

  final String label;
  final String ageRange;

  static ChildSection fromBirthDate(String value, {DateTime? today}) {
    final birthDate = DateTime.tryParse(value);
    final now = today ?? DateTime.now();
    if (birthDate == null || birthDate.isAfter(now)) {
      return ChildSection.ited;
    }

    var ageInMonths =
        (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) ageInMonths--;

    // The boundary changes exactly on each birthday: 0–35 months is ITED,
    // 36–47 months is Pre-Kinder 1, and 48 months onward is Pre-Kinder 2.
    // This keeps a child out of ITED as soon as they turn three.
    if (ageInMonths <= 35) return ChildSection.ited;
    if (ageInMonths <= 47) return ChildSection.preKinder1;
    return ChildSection.preKinder2;
  }
}

class ChildModel {
  final int? id;
  final String childId;
  final String firstName;
  final String lastName;
  final String? affix;
  final String birthDate;
  final int age;
  final String gender;
  final String address;
  final String parentName;
  final String teacherName;
  final String? parentUid;
  final String? teacherUid;
  final String status;
  final String updatedAt;
  final bool isSynced;
  final String? rfidUid;
  final bool rfidVerified;
  final String? rfidLinkedAt;

  ChildModel({
    this.id,
    required this.childId,
    required this.firstName,
    required this.lastName,
    this.affix,
    required this.birthDate,
    required this.age,
    required this.gender,
    required this.address,
    required this.parentName,
    required this.teacherName,
    this.parentUid,
    this.teacherUid,
    this.status = 'active',
    required this.updatedAt,
    this.isSynced = false,
    this.rfidUid,
    this.rfidVerified = false,
    this.rfidLinkedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'first_name': firstName,
      'last_name': lastName,
      'affix': affix,
      'birth_date': birthDate,
      'age': age,
      'gender': gender,
      'address': address,
      'parent_name': parentName,
      'teacher_name': teacherName,
      'parent_uid': parentUid,
      'teacher_uid': teacherUid,
      'status': status,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
      'rfid_uid': rfidUid,
      'rfid_verified': rfidVerified ? 1 : 0,
      'rfid_linked_at': rfidLinkedAt,
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    return ChildModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      affix: map['affix'] as String?,
      birthDate: map['birth_date'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      address: map['address'] ?? '',
      parentName: map['parent_name'] ?? '',
      teacherName: map['teacher_name'] ?? '',
      parentUid: map['parent_uid'] as String?,
      teacherUid: map['teacher_uid'] as String?,
      status: (map['status'] as String? ?? 'active').toLowerCase(),
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
      rfidUid: map['rfid_uid'] as String? ?? map['rfidUid'] as String?,
      rfidVerified:
          (map['rfid_verified'] ?? map['rfidVerified'] ?? 0) == 1 ||
          map['rfid_verified'] == true ||
          map['rfidVerified'] == true,
      rfidLinkedAt:
          map['rfid_linked_at'] as String? ?? map['rfidLinkedAt'] as String?,
    );
  }

  ChildModel copyWith({
    int? id,
    String? childId,
    String? firstName,
    String? lastName,
    String? affix,
    String? birthDate,
    int? age,
    String? gender,
    String? address,
    String? parentName,
    String? teacherName,
    String? parentUid,
    String? teacherUid,
    String? status,
    String? updatedAt,
    bool? isSynced,
    String? rfidUid,
    bool? rfidVerified,
    String? rfidLinkedAt,
    bool clearRfidLink = false,
  }) {
    return ChildModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      affix: affix ?? this.affix,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      parentName: parentName ?? this.parentName,
      teacherName: teacherName ?? this.teacherName,
      parentUid: parentUid ?? this.parentUid,
      teacherUid: teacherUid ?? this.teacherUid,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      rfidUid: clearRfidLink ? null : rfidUid ?? this.rfidUid,
      rfidVerified: rfidVerified ?? this.rfidVerified,
      rfidLinkedAt: clearRfidLink ? null : rfidLinkedAt ?? this.rfidLinkedAt,
    );
  }

  bool get isActive => status == 'active';

  /// The child's classroom section is derived from birth date, so it changes
  /// automatically as the child grows and never needs to be selected manually.
  ChildSection get section => ChildSection.fromBirthDate(birthDate);
}
