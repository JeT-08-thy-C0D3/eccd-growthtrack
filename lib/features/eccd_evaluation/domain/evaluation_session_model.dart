enum EvaluationSessionStatus {
  draft,
  inProgress,
  completed,
  reviewed,
  cancelled,
}

extension EvaluationSessionStatusX on EvaluationSessionStatus {
  String get value {
    switch (this) {
      case EvaluationSessionStatus.draft:
        return 'draft';
      case EvaluationSessionStatus.inProgress:
        return 'in_progress';
      case EvaluationSessionStatus.completed:
        return 'completed';
      case EvaluationSessionStatus.reviewed:
        return 'reviewed';
      case EvaluationSessionStatus.cancelled:
        return 'cancelled';
    }
  }

  static EvaluationSessionStatus fromValue(String? value) {
    for (final status in EvaluationSessionStatus.values) {
      if (status.value == value) return status;
    }
    return EvaluationSessionStatus.draft;
  }
}

class EvaluationSessionModel {
  final String id;
  final String childId;
  final String checklistVersion;
  final String evaluatorUid;
  final String? evaluatorRole;
  final EvaluationSessionStatus status;
  final String startedAt;
  final String? completedAt;
  final String createdAt;
  final String updatedAt;

  const EvaluationSessionModel({
    required this.id,
    required this.childId,
    required this.checklistVersion,
    required this.evaluatorUid,
    this.evaluatorRole,
    required this.status,
    required this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'checklist_version': checklistVersion,
      'evaluator_uid': evaluatorUid,
      'evaluator_role': evaluatorRole,
      'status': status.value,
      'started_at': startedAt,
      'completed_at': completedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory EvaluationSessionModel.fromMap(Map<String, dynamic> map) {
    return EvaluationSessionModel(
      id: map['id'] as String? ?? '',
      childId: map['child_id'] as String? ?? '',
      checklistVersion: map['checklist_version'] as String? ?? '',
      evaluatorUid: map['evaluator_uid'] as String? ?? '',
      evaluatorRole: map['evaluator_role'] as String?,
      status: EvaluationSessionStatusX.fromValue(map['status'] as String?),
      startedAt: map['started_at'] as String? ?? '',
      completedAt: map['completed_at'] as String?,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }
}
