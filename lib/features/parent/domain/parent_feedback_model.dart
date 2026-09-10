class ParentFeedbackModel {
  final int? id;
  final String childId;
  final int parentId;
  final String parentObservation;
  final String assistanceLevel;
  final String notes;
  final String submissionDate;

  ParentFeedbackModel({
    this.id,
    required this.childId,
    required this.parentId,
    required this.parentObservation,
    required this.assistanceLevel,
    required this.notes,
    required this.submissionDate,
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
    };
  }

  factory ParentFeedbackModel.fromMap(Map<String, dynamic> map) {
    return ParentFeedbackModel(
      id: map['id'],
      childId: map['child_id'],
      parentId: map['parent_id'],
      parentObservation: map['parent_observation'],
      assistanceLevel: map['assistance_level'],
      notes: map['notes'],
      submissionDate: map['submission_date'],
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
  }) {
    return ParentFeedbackModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      parentId: parentId ?? this.parentId,
      parentObservation: parentObservation ?? this.parentObservation,
      assistanceLevel: assistanceLevel ?? this.assistanceLevel,
      notes: notes ?? this.notes,
      submissionDate: submissionDate ?? this.submissionDate,
    );
  }
}
