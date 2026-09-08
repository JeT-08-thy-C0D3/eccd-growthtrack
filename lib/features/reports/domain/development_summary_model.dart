class DevelopmentSummaryModel {
  final int? id;
  final String childId;
  final int triangulationId;
  final String developmentSummary;
  final String strengthAreas;
  final String improvementAreas;
  final String suggestedHomeActivities;
  final String approvalStatus; // Pending, Approved, Rejected
  final String? approvedBy;
  final String? approvedDate;
  final String createdDate;

  DevelopmentSummaryModel({
    this.id,
    required this.childId,
    required this.triangulationId,
    required this.developmentSummary,
    required this.strengthAreas,
    required this.improvementAreas,
    required this.suggestedHomeActivities,
    required this.approvalStatus,
    this.approvedBy,
    this.approvedDate,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'triangulation_id': triangulationId,
      'development_summary': developmentSummary,
      'strength_areas': strengthAreas,
      'improvement_areas': improvementAreas,
      'suggested_home_activities': suggestedHomeActivities,
      'approval_status': approvalStatus,
      'approved_by': approvedBy,
      'approved_date': approvedDate,
      'created_date': createdDate,
    };
  }

  factory DevelopmentSummaryModel.fromMap(Map<String, dynamic> map) {
    return DevelopmentSummaryModel(
      id: map['id'],
      childId: map['child_id'],
      triangulationId: map['triangulation_id'],
      developmentSummary: map['development_summary'] ?? '',
      strengthAreas: map['strength_areas'] ?? '',
      improvementAreas: map['improvement_areas'] ?? '',
      suggestedHomeActivities: map['suggested_home_activities'] ?? '',
      approvalStatus: map['approval_status'] ?? 'Pending',
      approvedBy: map['approved_by'],
      approvedDate: map['approved_date'],
      createdDate: map['created_date'] ?? '',
    );
  }
}
