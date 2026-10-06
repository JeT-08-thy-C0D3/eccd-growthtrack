import '../entities/practice_activity.dart';
import '../repositories/practice_activity_repository.dart';

class CompletePracticeActivity {
  const CompletePracticeActivity(this.repository);

  final PracticeActivityRepository repository;

  Future<void> call({
    required PracticeActivity activity,
    required String parentUid,
    String? childId,
  }) {
    return repository.markCompleted(
      activity: activity,
      parentUid: parentUid,
      childId: childId,
    );
  }
}
