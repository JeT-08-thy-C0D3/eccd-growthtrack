class PracticeCompletion {
  const PracticeCompletion({
    this.id,
    required this.activityId,
    required this.activityTitle,
    required this.domainLabel,
    required this.parentUid,
    this.childId,
    required this.completedAt,
  });

  final int? id;
  final String activityId;
  final String activityTitle;
  final String domainLabel;
  final String parentUid;
  final String? childId;
  final DateTime completedAt;
}
