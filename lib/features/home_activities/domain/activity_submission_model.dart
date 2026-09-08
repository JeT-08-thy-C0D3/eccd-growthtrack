class ActivitySubmissionModel {
  final int? id;
  final int activityId;
  final String childId;
  final String evidencePath;
  final String parentNote;
  final String submissionDate;
  final String? teacherReview;
  final String reviewStatus; // Pending, Approved, Rejected

  ActivitySubmissionModel({
    this.id,
    required this.activityId,
    required this.childId,
    required this.evidencePath,
    required this.parentNote,
    required this.submissionDate,
    this.teacherReview,
    required this.reviewStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_id': activityId,
      'child_id': childId,
      'evidence_path': evidencePath,
      'parent_note': parentNote,
      'submission_date': submissionDate,
      'teacher_review': teacherReview,
      'review_status': reviewStatus,
    };
  }

  factory ActivitySubmissionModel.fromMap(Map<String, dynamic> map) {
    return ActivitySubmissionModel(
      id: map['id'],
      activityId: map['activity_id'],
      childId: map['child_id'],
      evidencePath: map['evidence_path'],
      parentNote: map['parent_note'],
      submissionDate: map['submission_date'],
      teacherReview: map['teacher_review'],
      reviewStatus: map['review_status'],
    );
  }
}
