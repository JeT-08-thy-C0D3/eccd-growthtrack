import '../../domain/entities/practice_completion.dart';

class PracticeCompletionModel extends PracticeCompletion {
  const PracticeCompletionModel({
    super.id,
    required super.activityId,
    required super.activityTitle,
    required super.domainLabel,
    required super.parentUid,
    super.childId,
    required super.completedAt,
  });

  factory PracticeCompletionModel.fromMap(Map<String, dynamic> map) {
    return PracticeCompletionModel(
      id: map['id'] as int?,
      activityId: map['activity_id'] as String,
      activityTitle: map['activity_title'] as String,
      domainLabel: map['domain_label'] as String,
      parentUid: map['parent_uid'] as String,
      childId: map['child_id'] as String?,
      completedAt: DateTime.parse(map['completed_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activity_id': activityId,
      'activity_title': activityTitle,
      'domain_label': domainLabel,
      'parent_uid': parentUid,
      'child_id': childId,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}
