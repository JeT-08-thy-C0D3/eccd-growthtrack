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
  final String updatedAt;
  final bool isSynced;

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
    required this.updatedAt,
    this.isSynced = false,
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
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory DevelopmentSummaryModel.fromMap(Map<String, dynamic> map) {
    return DevelopmentSummaryModel(
      id: map['id'],
      childId: map['child_id'] ?? '',
      triangulationId: map['triangulation_id'] ?? 0,
      developmentSummary: map['development_summary'] ?? '',
      strengthAreas: map['strength_areas'] ?? '',
      improvementAreas: map['improvement_areas'] ?? '',
      suggestedHomeActivities: map['suggested_home_activities'] ?? '',
      approvalStatus: map['approval_status'] ?? 'Pending',
      approvedBy: map['approved_by'],
      approvedDate: map['approved_date'],
      createdDate: map['created_date'] ?? '',
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  DevelopmentSummaryModel copyWith({
    int? id,
    String? childId,
    int? triangulationId,
    String? developmentSummary,
    String? strengthAreas,
    String? improvementAreas,
    String? suggestedHomeActivities,
    String? approvalStatus,
    String? approvedBy,
    String? approvedDate,
    String? createdDate,
    String? updatedAt,
    bool? isSynced,
  }) {
    return DevelopmentSummaryModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      triangulationId: triangulationId ?? this.triangulationId,
      developmentSummary: developmentSummary ?? this.developmentSummary,
      strengthAreas: strengthAreas ?? this.strengthAreas,
      improvementAreas: improvementAreas ?? this.improvementAreas,
      suggestedHomeActivities: suggestedHomeActivities ?? this.suggestedHomeActivities,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedDate: approvedDate ?? this.approvedDate,
      createdDate: createdDate ?? this.createdDate,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
