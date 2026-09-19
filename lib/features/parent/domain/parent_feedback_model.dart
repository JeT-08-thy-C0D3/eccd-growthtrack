class ParentFeedbackModel {
  final int? id;
  final String childId;
  final int parentId;
  final String parentObservation;
  final String assistanceLevel;
  final String notes;
  final String submissionDate;
  final String updatedAt;
  final bool isSynced;

  ParentFeedbackModel({
    this.id,
    required this.childId,
    required this.parentId,
    required this.parentObservation,
    required this.assistanceLevel,
    required this.notes,
    required this.submissionDate,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'parent_id': parentId,
      'parent_observation': parentObservation,
      'assistance_level': assistanceLevel,
      'notes': notes,
      'submission_date': submissionDate,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ParentFeedbackModel.fromMap(Map<String, dynamic> map) {
    return ParentFeedbackModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      parentId: map['parent_id'] ?? 0,
      parentObservation: map['parent_observation'] ?? '',
      assistanceLevel: map['assistance_level'] ?? '',
      notes: map['notes'] ?? '',
      submissionDate: map['submission_date'] ?? '',
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  ParentFeedbackModel copyWith({
    int? id,
    String? childId,
    int? parentId,
    String? parentObservation,
    String? assistanceLevel,
    String? notes,
    String? submissionDate,
    String? updatedAt,
    bool? isSynced,
  }) {
    return ParentFeedbackModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      parentId: parentId ?? this.parentId,
      parentObservation: parentObservation ?? this.parentObservation,
      assistanceLevel: assistanceLevel ?? this.assistanceLevel,
      notes: notes ?? this.notes,
      submissionDate: submissionDate ?? this.submissionDate,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
