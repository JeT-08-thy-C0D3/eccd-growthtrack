class ActivitySubmissionModel {
  final int? id;
  final int activityId;
  final String childId;
  final String parentNote;
  final String assistanceLevel; // Added as per requirements
  final String submissionDate;
  final String? teacherReview;
  final String reviewStatus; // Pending, Approved, Rejected
  final String updatedAt;
  final bool isSynced;

  ActivitySubmissionModel({
    this.id,
    required this.activityId,
    required this.childId,
    required this.parentNote,
    required this.assistanceLevel,
    required this.submissionDate,
    this.teacherReview,
    required this.reviewStatus,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_id': activityId,
      'child_id': childId,
      'parent_note': parentNote,
      'assistance_level': assistanceLevel,
      'submission_date': submissionDate,
      'teacher_review': teacherReview,
      'review_status': reviewStatus,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
      'storage_placeholder': null, // For future Firebase Storage integration
    };
  }

  factory ActivitySubmissionModel.fromMap(Map<String, dynamic> map) {
    return ActivitySubmissionModel(
      id: map['id'],
      activityId: map['activity_id'] ?? 0,
      childId: map['child_id'] ?? '',
      parentNote: map['parent_note'] ?? '',
      assistanceLevel: map['assistance_level'] ?? 'Independent',
      submissionDate: map['submission_date'] ?? '',
      teacherReview: map['teacher_review'],
      reviewStatus: map['review_status'] ?? 'Pending',
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  ActivitySubmissionModel copyWith({
    int? id,
    int? activityId,
    String? childId,
    String? parentNote,
    String? assistanceLevel,
    String? submissionDate,
    String? teacherReview,
    String? reviewStatus,
    String? updatedAt,
    bool? isSynced,
  }) {
    return ActivitySubmissionModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      childId: childId ?? this.childId,
      parentNote: parentNote ?? this.parentNote,
      assistanceLevel: assistanceLevel ?? this.assistanceLevel,
      submissionDate: submissionDate ?? this.submissionDate,
      teacherReview: teacherReview ?? this.teacherReview,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
