import '../entities/practice_completion.dart';
import '../repositories/practice_activity_repository.dart';

class GetCompletedPracticeActivities {
  const GetCompletedPracticeActivities(this.repository);

  final PracticeActivityRepository repository;

  Future<List<PracticeCompletion>> call({
    required String parentUid,
    String? childId,
  }) {
    return repository.getCompletions(parentUid: parentUid, childId: childId);
  }
}
