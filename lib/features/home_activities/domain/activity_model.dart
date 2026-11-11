class ActivityModel {
  final int? id;
  final String childId;
  final String activityTitle;
  final String developmentalDomain;
  final String instructions;
  final String dueDate;
  final String assignedBy;
  final String createdDate;
  final String status; // Assigned, Completed, Overdue
  final String updatedAt;
  final bool isSynced;
  final int maxScore;
  final bool evidenceRequired;
  final String? assignedTeacherUid;
  final String? parentUid;
  final String? section;

  ActivityModel({
    this.id,
    required this.childId,
    required this.activityTitle,
    this.developmentalDomain = 'General Development',
    required this.instructions,
    required this.dueDate,
    required this.assignedBy,
    required this.createdDate,
    required this.status,
    required this.updatedAt,
    this.isSynced = false,
    this.maxScore = 20,
    this.evidenceRequired = true,
    this.assignedTeacherUid,
    this.parentUid,
    this.section,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'activity_title': activityTitle,
      'developmental_domain': developmentalDomain,
      'instructions': instructions,
      'due_date': dueDate,
      'assigned_by': assignedBy,
      'created_date': createdDate,
      'status': status,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
      'max_score': maxScore,
      'evidence_required': evidenceRequired ? 1 : 0,
      'assigned_teacher_uid': assignedTeacherUid,
      'parent_uid': parentUid,
      'section': section,
    };
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      activityTitle: map['activity_title'] ?? '',
      developmentalDomain: map['developmental_domain'] ?? 'General Development',
      instructions: map['instructions'] ?? '',
      dueDate: map['due_date'] ?? '',
      assignedBy: map['assigned_by'] ?? '',
      createdDate: map['created_date'] ?? '',
      status: map['status'] ?? 'Assigned',
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
      maxScore: map['max_score'] as int? ?? 20,
      evidenceRequired:
          map['evidence_required'] == null ||
          map['evidence_required'] == true ||
          map['evidence_required'] == 1,
      assignedTeacherUid: map['assigned_teacher_uid'] as String?,
      parentUid: map['parent_uid'] as String?,
      section: map['section'] as String?,
    );
  }

  ActivityModel copyWith({
    int? id,
    String? childId,
    String? activityTitle,
    String? developmentalDomain,
    String? instructions,
    String? dueDate,
    String? assignedBy,
    String? createdDate,
    String? status,
    String? updatedAt,
    bool? isSynced,
    int? maxScore,
    bool? evidenceRequired,
    String? assignedTeacherUid,
    String? parentUid,
    String? section,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      activityTitle: activityTitle ?? this.activityTitle,
      developmentalDomain: developmentalDomain ?? this.developmentalDomain,
      instructions: instructions ?? this.instructions,
      dueDate: dueDate ?? this.dueDate,
      assignedBy: assignedBy ?? this.assignedBy,
      createdDate: createdDate ?? this.createdDate,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      maxScore: maxScore ?? this.maxScore,
      evidenceRequired: evidenceRequired ?? this.evidenceRequired,
      assignedTeacherUid: assignedTeacherUid ?? this.assignedTeacherUid,
      parentUid: parentUid ?? this.parentUid,
      section: section ?? this.section,
    );
  }
}
