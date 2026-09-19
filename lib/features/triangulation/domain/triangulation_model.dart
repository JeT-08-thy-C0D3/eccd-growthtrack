class TriangulationModel {
  final int? id;
  final String childId;
  final String teacherAssessmentSummary;
  final String parentFeedbackSummary;
  final String historicalRecordSummary;
  final String triangulatedSummary;
  final String developmentStatus;
  final String generatedDate;
  final String updatedAt;
  final bool isSynced;

  TriangulationModel({
    this.id,
    required this.childId,
    required this.teacherAssessmentSummary,
    required this.parentFeedbackSummary,
    required this.historicalRecordSummary,
    required this.triangulatedSummary,
    required this.developmentStatus,
    required this.generatedDate,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'teacher_assessment_summary': teacherAssessmentSummary,
      'parent_feedback_summary': parentFeedbackSummary,
      'historical_record_summary': historicalRecordSummary,
      'triangulated_summary': triangulatedSummary,
      'development_status': developmentStatus,
      'generated_date': generatedDate,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory TriangulationModel.fromMap(Map<String, dynamic> map) {
    return TriangulationModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      teacherAssessmentSummary: map['teacher_assessment_summary'] ?? '',
      parentFeedbackSummary: map['parent_feedback_summary'] ?? '',
      historicalRecordSummary: map['historical_record_summary'] ?? '',
      triangulatedSummary: map['triangulated_summary'] ?? '',
      developmentStatus: map['development_status'] ?? 'On Track',
      generatedDate: map['generated_date'] ?? '',
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  TriangulationModel copyWith({
    int? id,
    String? childId,
    String? teacherAssessmentSummary,
    String? parentFeedbackSummary,
    String? historicalRecordSummary,
    String? triangulatedSummary,
    String? developmentStatus,
    String? generatedDate,
    String? updatedAt,
    bool? isSynced,
  }) {
    return TriangulationModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      teacherAssessmentSummary: teacherAssessmentSummary ?? this.teacherAssessmentSummary,
      parentFeedbackSummary: parentFeedbackSummary ?? this.parentFeedbackSummary,
      historicalRecordSummary: historicalRecordSummary ?? this.historicalRecordSummary,
      triangulatedSummary: triangulatedSummary ?? this.triangulatedSummary,
      developmentStatus: developmentStatus ?? this.developmentStatus,
      generatedDate: generatedDate ?? this.generatedDate,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
