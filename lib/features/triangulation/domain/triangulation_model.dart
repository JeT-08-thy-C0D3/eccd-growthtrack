class TriangulationModel {
  final int? id;
  final String childId;
  final String teacherAssessmentSummary;
  final String parentFeedbackSummary;
  final String historicalRecordSummary;
  final String triangulatedSummary;
  final String developmentStatus;
  final String generatedDate;

  TriangulationModel({
    this.id,
    required this.childId,
    required this.teacherAssessmentSummary,
    required this.parentFeedbackSummary,
    required this.historicalRecordSummary,
    required this.triangulatedSummary,
    required this.developmentStatus,
    required this.generatedDate,
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
    };
  }

  factory TriangulationModel.fromMap(Map<String, dynamic> map) {
    return TriangulationModel(
      id: map['id'],
      childId: map['child_id'],
      teacherAssessmentSummary: map['teacher_assessment_summary'],
      parentFeedbackSummary: map['parent_feedback_summary'],
      historicalRecordSummary: map['historical_record_summary'],
      triangulatedSummary: map['triangulated_summary'],
      developmentStatus: map['development_status'],
      generatedDate: map['generated_date'],
    );
  }
}
