class ActivitySubmissionModel {
  final int? id;
  final int activityId;
  final String childId;
  final String parentNote;
  final String assistanceLevel;
  final String submissionDate;
  final String? teacherReview;
  final String reviewStatus; // Pending, Approved, Rejected
  final String updatedAt;
  final bool isSynced;
  final int? score;
  final String? evidenceUrl;
  final String? evidenceMediaType;
  final String? evidenceFileName;
  final String? teacherUid;
  final String? parentUid;

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
    this.score,
    this.evidenceUrl,
    this.evidenceMediaType,
    this.evidenceFileName,
    this.teacherUid,
    this.parentUid,
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
      'storage_placeholder': null,
      'evidence_url': evidenceUrl,
      'evidence_media_type': evidenceMediaType,
      'evidence_file_name': evidenceFileName,
      'teacher_uid': teacherUid,
      'parent_uid': parentUid,
      'score': score,
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
      score: map['score'] as int?,
      evidenceUrl: map['evidence_url'] as String?,
      evidenceMediaType: map['evidence_media_type'] as String?,
      evidenceFileName: map['evidence_file_name'] as String?,
      teacherUid: map['teacher_uid'] as String?,
      parentUid: map['parent_uid'] as String?,
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
    int? score,
    String? evidenceUrl,
    String? evidenceMediaType,
    String? evidenceFileName,
    String? teacherUid,
    String? parentUid,
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
      score: score ?? this.score,
      evidenceUrl: evidenceUrl ?? this.evidenceUrl,
      evidenceMediaType: evidenceMediaType ?? this.evidenceMediaType,
      evidenceFileName: evidenceFileName ?? this.evidenceFileName,
      teacherUid: teacherUid ?? this.teacherUid,
      parentUid: parentUid ?? this.parentUid,
    );
  }
}
