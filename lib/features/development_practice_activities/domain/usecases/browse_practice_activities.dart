import '../entities/practice_activity.dart';
import '../repositories/practice_activity_repository.dart';

class BrowsePracticeActivities {
  const BrowsePracticeActivities(this.repository);

  final PracticeActivityRepository repository;

  Future<List<PracticeActivity>> call({PracticeDomain? domain}) {
    return repository.getActivities(domain: domain);
  }
}
